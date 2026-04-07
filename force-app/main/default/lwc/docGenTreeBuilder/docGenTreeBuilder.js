import { LightningElement, track, api } from 'lwc';
import getObjectFields from '@salesforce/apex/DocGenController.getObjectFields';
import getChildRelationships from '@salesforce/apex/DocGenController.getChildRelationships';
import getParentRelationships from '@salesforce/apex/DocGenController.getParentRelationships';
import { parseSOQLFields } from 'c/docGenUtils';

/**
 * Tree-based visual query builder. Renders a recursive tree of nodes —
 * each node shows selected field pills, a compact field picker, parent
 * lookup folders, and child relationship folders. Same component pattern
 * at every level. Outputs a flat SOQL-style field string.
 */
export default class DocGenTreeBuilder extends LightningElement {

    // ── API ──────────────────────────────────────────────────────
    @api
    get selectedObject() { return this._selectedObject; }
    set selectedObject(val) {
        if (val && val !== this._selectedObject) {
            this._selectedObject = val;
            this._initRoot();
        }
    }
    _selectedObject;

    @api
    get queryConfig() { return this._buildQueryString(); }
    set queryConfig(val) {
        this._pendingConfig = val;
        if (this._rootLoaded) { this._parseIncoming(val); }
    }

    // ── Internal state ──────────────────────────────────────────
    @track _root = null;  // root node data
    @track _globalSearch = '';
    _rootLoaded = false;
    _pendingConfig = null;
    _suppressNotify = false;
    _schemaCache = {};

    handleGlobalSearch(event) {
        this._globalSearch = (event.target.value || '').toLowerCase();
    }

    get globalSearch() { return this._globalSearch; }

    // ── Root init ───────────────────────────────────────────────
    async _initRoot() {
        const obj = this._selectedObject;
        if (!obj) return;
        const schema = await this._loadSchema(obj);
        this._root = this._makeNode('root', obj, obj, schema, false);
        this._rootLoaded = true;
        if (this._pendingConfig) {
            await this._parseIncoming(this._pendingConfig);
            this._pendingConfig = null;
        }
        this._refresh();
    }

    _makeNode(path, objectName, objectLabel, schema, isChild) {
        return {
            path,
            objectName,
            objectLabel,
            isChild,
            fields: schema.fields.map(f => ({
                apiName: f.value,
                displayLabel: this._extractLabel(f.label),
                type: f.type,
                label: f.label,
                checked: false
            })),
            parentRels: schema.parents.map(p => ({
                value: p.value,
                displayLabel: this._extractLabel(p.label),
                label: p.label,
                targetObject: p.targetObject,
                icon: 'utility:chevronright',
                expanded: false,
                fields: null  // lazy
            })),
            childRels: schema.children.map(c => ({
                value: c.value,
                displayLabel: this._extractRelLabel(c.label),
                label: c.label,
                childObjectApiName: c.childObjectApiName,
                lookupField: c.lookupField,
                icon: 'utility:chevronright',
                expanded: false,
                nodeData: null,  // lazy
                hasNode: false
            })),
            whereClause: '',
            orderBy: '',
            limitAmount: ''
        };
    }

    // ── Schema cache ────────────────────────────────────────────
    async _loadSchema(objectName) {
        if (this._schemaCache[objectName]) return this._schemaCache[objectName];
        const [fields, children, parents] = await Promise.all([
            getObjectFields({ objectName }),
            getChildRelationships({ objectName }),
            getParentRelationships({ objectName })
        ]);
        const schema = { fields, children, parents };
        this._schemaCache[objectName] = schema;
        return schema;
    }

    // ── Event handlers (from tree nodes) ────────────────────────
    handleNodeFieldToggle(event) {
        event.stopPropagation();
        const { path, fieldName } = event.detail;
        const node = this._resolveNode(path);
        if (!node) return;
        const field = node.fields.find(f => f.apiName === fieldName);
        if (field) { field.checked = !field.checked; }
        this._refresh();
        this._notifyChange();
    }

    handleNodeParentFieldToggle(event) {
        event.stopPropagation();
        const { path, relName, fieldName } = event.detail;
        const node = this._resolveNode(path);
        if (!node) return;
        const pr = node.parentRels.find(p => p.value === relName);
        if (!pr || !pr.fields) return;
        const field = pr.fields.find(f => f.apiName === fieldName);
        if (field) { field.checked = !field.checked; }
        this._refresh();
        this._notifyChange();
    }

    async handleNodeExpandChild(event) {
        event.stopPropagation();
        const { path, relName } = event.detail;
        const node = this._resolveNode(path);
        if (!node) return;
        const cr = node.childRels.find(c => c.value === relName);
        if (!cr) return;

        if (cr.expanded) {
            cr.expanded = false;
            cr.icon = 'utility:chevronright';
        } else {
            if (!cr.nodeData) {
                const schema = await this._loadSchema(cr.childObjectApiName);
                const childPath = path + '.child:' + relName;
                cr.nodeData = this._makeNode(childPath, cr.childObjectApiName, cr.displayLabel, schema, true);
                cr.hasNode = true;
            }
            cr.expanded = true;
            cr.icon = 'utility:chevrondown';
        }
        this._refresh();
    }

    async handleNodeExpandParent(event) {
        event.stopPropagation();
        const { path, relName } = event.detail;
        const node = this._resolveNode(path);
        if (!node) return;
        const pr = node.parentRels.find(p => p.value === relName);
        if (!pr) return;

        if (pr.expanded) {
            pr.expanded = false;
            pr.icon = 'utility:chevronright';
        } else {
            if (!pr.fields) {
                const schema = await this._loadSchema(pr.targetObject);
                pr.fields = schema.fields.map(f => ({
                    apiName: f.value,
                    displayLabel: this._extractLabel(f.label),
                    label: f.label,
                    type: f.type,
                    checked: false
                }));
            }
            pr.expanded = true;
            pr.icon = 'utility:chevrondown';
        }
        this._refresh();
    }

    handleNodeRemoveChild(event) {
        event.stopPropagation();
        const { path, relName } = event.detail;
        const node = this._resolveNode(path);
        if (!node) return;
        const cr = node.childRels.find(c => c.value === relName);
        if (!cr) return;
        // Collapse and discard all selections
        cr.expanded = false;
        cr.icon = 'utility:chevronright';
        cr.nodeData = null;
        cr.hasNode = false;
        this._refresh();
        this._notifyChange();
    }

    handleNodeRemoveParent(event) {
        event.stopPropagation();
        const { path, relName } = event.detail;
        const node = this._resolveNode(path);
        if (!node) return;
        const pr = node.parentRels.find(p => p.value === relName);
        if (!pr) return;
        // Collapse and uncheck all fields
        pr.expanded = false;
        pr.icon = 'utility:chevronright';
        if (pr.fields) {
            for (const f of pr.fields) { f.checked = false; }
        }
        this._refresh();
        this._notifyChange();
    }

    handleNodeClauseChange(event) {
        event.stopPropagation();
        const { path, field, value } = event.detail;
        const node = this._resolveNode(path);
        if (node) { node[field] = value; }
        this._notifyChange();
    }

    // ── Node resolution ─────────────────────────────────────────
    _resolveNode(pathStr) {
        if (!this._root || !pathStr) return null;
        const parts = pathStr.split('.');
        let node = this._root;
        for (let i = 1; i < parts.length; i++) {
            const part = parts[i];
            if (part.startsWith('child:')) {
                const relName = part.substring(6);
                const cr = node.childRels.find(c => c.value === relName);
                if (cr && cr.nodeData) { node = cr.nodeData; }
                else return null;
            }
        }
        return node;
    }

    // ── Build query string ──────────────────────────────────────
    _buildQueryString() {
        if (!this._root) return '';
        const parts = [];
        this._collectFields(this._root, parts);
        return parts.join(', ');
    }

    _collectFields(node, parts) {
        // Base fields
        for (const f of node.fields) {
            if (f.checked) parts.push(f.apiName);
        }
        // Parent fields
        for (const pr of node.parentRels) {
            if (!pr.fields) continue;
            for (const f of pr.fields) {
                if (f.checked) parts.push(pr.value + '.' + f.apiName);
            }
        }
        // Child subqueries
        for (const cr of node.childRels) {
            if (!cr.nodeData) continue;
            const sub = this._buildSubquery(cr.nodeData);
            if (sub) parts.push(sub);
        }
    }

    _buildSubquery(node) {
        const fieldParts = [];
        this._collectFields(node, fieldParts);
        if (fieldParts.length === 0) return null;

        let sq = '(SELECT ' + fieldParts.join(', ') + ' FROM ' + node.path.split('.').pop().replace('child:', '');
        // Use the relationship name from the last path segment
        const pathParts = node.path.split('.');
        const lastPart = pathParts[pathParts.length - 1];
        const relName = lastPart.startsWith('child:') ? lastPart.substring(6) : lastPart;
        sq = '(SELECT ' + fieldParts.join(', ') + ' FROM ' + relName;
        if (node.whereClause) sq += ' WHERE ' + node.whereClause;
        if (node.orderBy) sq += ' ORDER BY ' + node.orderBy;
        if (node.limitAmount) sq += ' LIMIT ' + node.limitAmount;
        sq += ')';
        return sq;
    }

    // ── Parse incoming config ───────────────────────────────────
    async _parseIncoming(configStr) {
        if (!configStr || !this._root) return;
        this._suppressNotify = true;

        const parsed = parseSOQLFields(configStr);

        // Reset
        this._uncheckAll(this._root);

        // Check root base fields
        for (const fname of parsed.baseFields) {
            const f = this._root.fields.find(ff => ff.apiName === fname);
            if (f) f.checked = true;
        }

        // Check root parent fields
        for (const pf of parsed.parentFields) {
            const dotIdx = pf.indexOf('.');
            if (dotIdx === -1) continue;
            const relName = pf.substring(0, dotIdx);
            const fieldName = pf.substring(dotIdx + 1);
            const pr = this._root.parentRels.find(p => p.value === relName);
            if (pr) { await this._expandAndCheckParentField(pr, fieldName); }
        }

        // Expand child relationships
        for (const sq of parsed.subqueries) {
            await this._expandAndCheckChild(this._root, sq);
        }

        this._suppressNotify = false;
        this._refresh();
    }

    _uncheckAll(node) {
        for (const f of node.fields) { f.checked = false; }
        for (const pr of node.parentRels) {
            if (pr.fields) { for (const f of pr.fields) { f.checked = false; } }
        }
        for (const cr of node.childRels) {
            if (cr.nodeData) { this._uncheckAll(cr.nodeData); }
        }
    }

    async _expandAndCheckParentField(parentRel, fieldName) {
        if (!parentRel.fields) {
            const schema = await this._loadSchema(parentRel.targetObject);
            parentRel.fields = schema.fields.map(f => ({
                apiName: f.value,
                displayLabel: this._extractLabel(f.label),
                label: f.label,
                type: f.type,
                checked: false
            }));
        }
        parentRel.expanded = true;
        parentRel.icon = 'utility:chevrondown';
        const field = parentRel.fields.find(f => f.apiName === fieldName);
        if (field) field.checked = true;
    }

    async _expandAndCheckChild(parentNode, subquery) {
        const cr = parentNode.childRels.find(c => c.value === subquery.relationshipName);
        if (!cr) return;

        if (!cr.nodeData) {
            const schema = await this._loadSchema(cr.childObjectApiName);
            const childPath = parentNode.path + '.child:' + subquery.relationshipName;
            cr.nodeData = this._makeNode(childPath, cr.childObjectApiName, cr.displayLabel, schema, true);
            cr.hasNode = true;
        }
        cr.expanded = true;
        cr.icon = 'utility:chevrondown';

        cr.nodeData.whereClause = subquery.whereClause || '';
        cr.nodeData.orderBy = subquery.orderBy || '';
        cr.nodeData.limitAmount = subquery.limitAmount || '';

        for (const fieldName of subquery.fields) {
            if (fieldName.includes('.')) {
                const dotIdx = fieldName.indexOf('.');
                const relName = fieldName.substring(0, dotIdx);
                const fName = fieldName.substring(dotIdx + 1);
                const pr = cr.nodeData.parentRels.find(p => p.value === relName);
                if (pr) { await this._expandAndCheckParentField(pr, fName); }
            } else {
                const f = cr.nodeData.fields.find(ff => ff.apiName === fieldName);
                if (f) f.checked = true;
            }
        }

        if (subquery.children) {
            for (const nested of subquery.children) {
                await this._expandAndCheckChild(cr.nodeData, nested);
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────
    _extractLabel(rawLabel) {
        if (!rawLabel) return '';
        const idx = rawLabel.lastIndexOf('(');
        return idx > 0 ? rawLabel.substring(0, idx).trim() : rawLabel;
    }

    _extractRelLabel(rawLabel) {
        if (!rawLabel) return '';
        const idx = rawLabel.lastIndexOf('(');
        return idx > 0 ? rawLabel.substring(idx + 1).replace(')', '').trim() : rawLabel;
    }

    _refresh() {
        // Deep clone to force LWC reactivity at all nesting depths.
        // Node data is plain objects (no functions/circular refs) so JSON round-trip is safe.
        this._root = this._root ? JSON.parse(JSON.stringify(this._root)) : null;
    }

    _notifyChange() {
        if (this._suppressNotify) return;
        this.dispatchEvent(new CustomEvent('configchange', {
            detail: {
                objectName: this._selectedObject,
                queryConfig: this._buildQueryString()
            }
        }));
    }

    // ── Template getters ────────────────────────────────────────
    get hasRoot() { return !!this._root; }

    get rootNodeData() { return this._root; }

    get selectedCount() {
        if (!this._root) return 0;
        return this._countAll(this._root);
    }

    _countAll(node) {
        let c = 0;
        for (const f of node.fields) { if (f.checked) c++; }
        for (const pr of node.parentRels) {
            if (pr.fields) { for (const f of pr.fields) { if (f.checked) c++; } }
        }
        for (const cr of node.childRels) {
            if (cr.nodeData) c += this._countAll(cr.nodeData);
        }
        return c;
    }
}
