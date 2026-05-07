# Sales Process Automation Development Plan

## 0) Goal and Scope

Implement an end-to-end Salesforce sales process from Lead to Renewal with clear boundaries between native platform capabilities and custom development.

## 1) Business Flow (Target State)

1. Lead capture and qualification
2. Lead conversion to Account, Contact, and Opportunity
3. Opportunity management with products and contact roles
4. Quote creation, approval, and customer acceptance
5. Order creation and fulfillment handoff
6. Contract generation and legal archive
7. Invoice, Payment, and Shipment synchronization from ERP
8. Ordered products become Assets
9. Renewal, Amendment, and Termination lifecycle

## 2) Standard vs Custom (Decision Matrix)

### Standard Salesforce (Configuration)

- Lead conversion (Account, Contact, optional Opportunity)
- Opportunity with Products (OpportunityLineItems)
- Quote object and Quote Line Items
- Synced Quote behavior for Opportunity and Quote alignment
- Order and Order Products objects (when enabled)

### Requires Automation or Development

- Mass lead conversion orchestration with duplicate-safe rules
- Auto Price Book assignment on Opportunity by segment, region, year
- Product-interest to OpportunityLineItem mapping
- Auto-create primary Opportunity Contact Role
- Annual Price Book rollover with percentage uplift and exceptions
- Quote-to-Order automatic line copy with validation and idempotency
- Closed Won Opportunity to Contract creation and PDF generation
- Custom Quote PDF template and rendering controls
- ERP integration for Invoice, Payment, Shipment status updates
- Order-to-Asset automation and lifecycle updates
- Renewal, Amendment, and Termination playbooks and automations

## 3) Delivery Phases

### Phase 1: Foundation (High Priority)

✅ **COMPLETED: Lead capture and qualification**
   - Web-to-Lead implementation with React site
   - Lead insert trigger with Metillium framework
   - Product Interest field mapping from web form

1. Lead conversion baseline and field mappings
2. Opportunity defaults
   - Auto-set Price Book
   - Auto-create primary Opportunity Contact Role
3. Product-interest mapping to OpportunityLineItems

### Phase 2: Commercial Core (High Priority)

4. Price Book new-year actualization
   - Clone previous year entries
   - Apply percentage uplift
   - Support exclusions and rounding policy
5. Quote-to-Order automation
   - Header validation (Account, dates, status, approved quote)
   - Quote Line Items to Order Products copy
   - Prevent duplicate order creation

### Phase 3: Contracting and Documents (Medium Priority)

6. Opportunity-to-Contract on Closed Won
   - Contract terms mapping
   - Contract PDF custom Visualforce
7. Quote PDF custom Visualforce
   - Branded template
   - Taxes, discounts, legal text sections

### Phase 4: Post-Sales Operations (High Priority)

8. ERP integration
   - Invoices
   - Payments
   - Shipments
   - Error retry and reconciliation dashboard
9. Order-to-Assets
   - Ordered products become Assets
   - Warranty or term dates and entitlement linkage

### Phase 5: Lifecycle Management (Medium Priority)

10. Renewal, Amendment, Termination options
    - Renewal opportunity generation schedule
    - Amendment delta handling
    - Termination status and asset deactivation

## 4) Suggested Implementation Pattern (Flow First, Apex Where Needed)

Use Record-Triggered Flows for straightforward field updates and object creation.

Use Apex for:

- Bulk-safe line-item copying
- Complex validations
- Retryable integration orchestration
- PDF generation controllers

## 5) Object and Line-Item Sync Rules

- Opportunity Products and Synced Quote Line Items: native synchronization available
- Quote Line Items to Order Products: implement custom automation (Flow or Apex) for reliability and controls
- Order Products to Assets: implement custom automation with lifecycle rules

## 6) Governance, Security, and Quality

- Permission Sets for Sales Ops, Sales Rep, Finance Ops, Service Ops
- Validation Rules for stage gates and required commercial data
- Apex tests for all custom logic (line copy, contract creation, integration handlers)
- UAT scripts per phase and release checklist

## 7) Backlog (Refined From Current Notes)

✅ **COMPLETED: Web-to-Lead Implementation**
   - React site with Lead capture form (https://react-for-fun.vercel.app/)
   - Web-to-Lead integration with Salesforce
   - Lead insert trigger using Metillium framework
   - Product Interest field mapping (Description → Product Interest)

1. Mass convert Leads
   - Auto-set Price Book on Opportunity
   - Set OpportunityLineItems by product interest
   - Auto-fill Opportunity Contact Role
2. Actualize new-year Price Book by percentage of previous year
3. Quote-to-Order
   - Auto-copy Quote Line Items to Order Products
4. Opportunity-to-Contract
   - Closed Won Opportunity creates Contract with custom PDF
5. Quote PDF custom Visualforce
6. Invoice-Payment-Shipment ERP integration
7. Order-to-Assets
   - Ordered products become Assets
8. Renewal, Amendment, Termination options

## 8) Milestones and Acceptance

✅ **Milestone 0: Web-to-Lead Implementation Complete**
   - React site with Lead capture form deployed
   - Web-to-Lead integration working
   - Lead insert trigger implemented with Metillium framework
   - Product Interest field mapping functional

- Milestone A: Lead-to-Opportunity automation complete and tested
- Milestone B: Quote-to-Order with line items complete and tested
- Milestone C: Contract and PDF generation complete and approved
- Milestone D: ERP synchronization complete with monitoring
- Milestone E: Order-to-Asset and Renewal automation complete

## 9) Risks and Mitigations

- Data quality risk: enforce validation and picklist normalization
- Duplicate transaction risk: use external IDs and idempotent keys
- Integration latency risk: async queue with retries and dead-letter reporting
- Pricing drift risk: annual rollover audit report and approval step

## 10) Recommended Build Order

1. Phase 1 foundation
2. Quote-to-Order line automation
3. Contract and PDF generation
4. ERP integration
5. Lifecycle automation (renewal, amendment, termination)
