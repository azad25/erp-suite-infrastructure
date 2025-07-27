const { gql } = require('apollo-server-express');

const typeDefs = gql`
  # Scalars
  scalar DateTime
  scalar JSON
  scalar Upload

  # Directives for caching and performance
  directive @cacheControl(maxAge: Int, scope: CacheControlScope) on FIELD_DEFINITION | OBJECT | INTERFACE
  directive @rateLimit(max: Int!, window: String!, message: String) on FIELD_DEFINITION
  directive @auth(requires: Role = USER) on FIELD_DEFINITION | OBJECT

  enum CacheControlScope {
    PUBLIC
    PRIVATE
  }

  enum Role {
    ADMIN
    MANAGER
    USER
    GUEST
  }

  # Common types
  type PageInfo {
    hasNextPage: Boolean!
    hasPreviousPage: Boolean!
    startCursor: String
    endCursor: String
  }

  input PaginationInput {
    first: Int
    after: String
    last: Int
    before: String
  }

  input SortInput {
    field: String!
    direction: SortDirection!
  }

  enum SortDirection {
    ASC
    DESC
  }

  # User Management
  type User @cacheControl(maxAge: 300) {
    id: ID!
    email: String!
    name: String!
    role: Role!
    avatar: String
    isActive: Boolean!
    lastLogin: DateTime
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relationships (optimized with DataLoader)
    profile: UserProfile
    permissions: [Permission!]!
    organization: Organization
  }

  type UserProfile {
    id: ID!
    firstName: String!
    lastName: String!
    phone: String
    department: String
    position: String
    bio: String
  }

  type Permission {
    id: ID!
    name: String!
    resource: String!
    action: String!
  }

  type Organization @cacheControl(maxAge: 600) {
    id: ID!
    name: String!
    domain: String!
    plan: SubscriptionPlan!
    settings: JSON
    createdAt: DateTime!
  }

  type UserConnection {
    edges: [UserEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type UserEdge {
    node: User!
    cursor: String!
  }

  input UserFilter {
    search: String
    role: Role
    isActive: Boolean
    organizationId: ID
  }

  # CRM Module
  type Contact @cacheControl(maxAge: 180) {
    id: ID!
    name: String!
    email: String
    phone: String
    company: String
    position: String
    source: String
    tags: [String!]!
    customFields: JSON
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relationships
    leads: [Lead!]!
    opportunities: [Opportunity!]!
    activities: [Activity!]!
    assignedTo: User
  }

  type Lead {
    id: ID!
    title: String!
    status: LeadStatus!
    source: String!
    value: Float
    probability: Int
    expectedCloseDate: DateTime
    notes: String
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relationships
    contact: Contact!
    assignedTo: User
    activities: [Activity!]!
  }

  enum LeadStatus {
    NEW
    QUALIFIED
    PROPOSAL
    NEGOTIATION
    CLOSED_WON
    CLOSED_LOST
  }

  type Opportunity {
    id: ID!
    title: String!
    stage: OpportunityStage!
    value: Float!
    probability: Int!
    expectedCloseDate: DateTime!
    actualCloseDate: DateTime
    description: String
    
    # Relationships
    contact: Contact!
    assignedTo: User!
    products: [Product!]!
  }

  enum OpportunityStage {
    PROSPECTING
    QUALIFICATION
    PROPOSAL
    NEGOTIATION
    CLOSED_WON
    CLOSED_LOST
  }

  # HRM Module
  type Employee @cacheControl(maxAge: 300) {
    id: ID!
    employeeId: String!
    firstName: String!
    lastName: String!
    email: String!
    phone: String
    position: String!
    department: Department!
    manager: Employee
    hireDate: DateTime!
    salary: Float
    status: EmployeeStatus!
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relationships
    leaves: [Leave!]!
    timesheets: [Timesheet!]!
    performance: [PerformanceReview!]!
  }

  type Timesheet {
    id: ID!
    date: DateTime!
    hoursWorked: Float!
    description: String
    status: TimesheetStatus!
    submittedAt: DateTime
    approvedAt: DateTime
    
    employee: Employee!
    approvedBy: Employee
  }

  enum TimesheetStatus {
    DRAFT
    SUBMITTED
    APPROVED
    REJECTED
  }

  type PerformanceReview {
    id: ID!
    reviewPeriod: String!
    overallRating: Int!
    goals: [String!]!
    achievements: [String!]!
    areasForImprovement: [String!]!
    comments: String
    status: ReviewStatus!
    reviewDate: DateTime!
    
    employee: Employee!
    reviewer: Employee!
  }

  enum ReviewStatus {
    DRAFT
    IN_PROGRESS
    COMPLETED
    APPROVED
  }

  type Department {
    id: ID!
    name: String!
    description: String
    manager: Employee
    employees: [Employee!]!
    budget: Float
  }

  enum EmployeeStatus {
    ACTIVE
    INACTIVE
    TERMINATED
    ON_LEAVE
  }

  type Leave {
    id: ID!
    type: LeaveType!
    startDate: DateTime!
    endDate: DateTime!
    days: Int!
    status: LeaveStatus!
    reason: String
    approvedBy: Employee
    
    employee: Employee!
  }

  enum LeaveType {
    ANNUAL
    SICK
    MATERNITY
    PATERNITY
    EMERGENCY
  }

  enum LeaveStatus {
    PENDING
    APPROVED
    REJECTED
    CANCELLED
  }

  # Finance Module
  type Invoice @cacheControl(maxAge: 120) {
    id: ID!
    invoiceNumber: String!
    status: InvoiceStatus!
    issueDate: DateTime!
    dueDate: DateTime!
    subtotal: Float!
    taxAmount: Float!
    totalAmount: Float!
    currency: String!
    notes: String
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relationships
    customer: Contact!
    lineItems: [InvoiceLineItem!]!
    payments: [Payment!]!
  }

  type InvoiceLineItem {
    id: ID!
    description: String!
    quantity: Int!
    unitPrice: Float!
    taxRate: Float!
    amount: Float!
    
    product: Product
  }

  enum InvoiceStatus {
    DRAFT
    SENT
    PAID
    OVERDUE
    CANCELLED
  }

  type Payment {
    id: ID!
    amount: Float!
    paymentDate: DateTime!
    method: PaymentMethod!
    reference: String
    status: PaymentStatus!
    
    invoice: Invoice!
  }

  enum PaymentMethod {
    CASH
    CREDIT_CARD
    BANK_TRANSFER
    CHECK
    PAYPAL
    STRIPE
  }

  enum PaymentStatus {
    PENDING
    COMPLETED
    FAILED
    REFUNDED
  }

  # Inventory Module
  type Product @cacheControl(maxAge: 600) {
    id: ID!
    sku: String!
    name: String!
    description: String
    category: ProductCategory!
    price: Float!
    cost: Float
    stockQuantity: Int!
    minStockLevel: Int!
    isActive: Boolean!
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relationships
    supplier: Supplier
    stockMovements: [StockMovement!]!
  }

  type ProductCategory {
    id: ID!
    name: String!
    description: String
    parent: ProductCategory
    children: [ProductCategory!]!
  }

  type Supplier {
    id: ID!
    name: String!
    email: String
    phone: String
    address: String
    
    products: [Product!]!
  }

  type StockMovement {
    id: ID!
    type: MovementType!
    quantity: Int!
    reference: String
    notes: String
    createdAt: DateTime!
    
    product: Product!
    user: User!
  }

  enum MovementType {
    IN
    OUT
    ADJUSTMENT
    TRANSFER
  }

  # Subscription Management
  type SubscriptionPlan {
    id: ID!
    name: String!
    price: Float!
    billingCycle: BillingCycle!
    features: [String!]!
    limits: JSON!
    isActive: Boolean!
  }

  enum BillingCycle {
    MONTHLY
    YEARLY
  }

  # Real-time Activity Feed
  type Activity {
    id: ID!
    type: ActivityType!
    title: String!
    description: String
    metadata: JSON
    createdAt: DateTime!
    
    # Relationships
    user: User!
    relatedEntity: ActivityEntity
  }

  enum ActivityType {
    USER_LOGIN
    CONTACT_CREATED
    LEAD_UPDATED
    INVOICE_SENT
    PAYMENT_RECEIVED
    EMPLOYEE_HIRED
    PRODUCT_UPDATED
  }

  union ActivityEntity = Contact | Lead | Invoice | Employee | Product

  # Root Query
  type Query {
    # User queries
    me: User @auth
    users(
      filter: UserFilter
      pagination: PaginationInput
      sort: SortInput
    ): UserConnection @auth(requires: MANAGER) @cacheControl(maxAge: 300)
    
    user(id: ID!): User @auth @cacheControl(maxAge: 300)
    
    # CRM queries
    contacts(
      filter: ContactFilter
      pagination: PaginationInput
      sort: SortInput
    ): ContactConnection @auth @cacheControl(maxAge: 180)
    
    contact(id: ID!): Contact @auth @cacheControl(maxAge: 180)
    
    leads(
      filter: LeadFilter
      pagination: PaginationInput
      sort: SortInput
    ): LeadConnection @auth @cacheControl(maxAge: 120)
    
    # HRM queries
    employees(
      filter: EmployeeFilter
      pagination: PaginationInput
      sort: SortInput
    ): EmployeeConnection @auth @cacheControl(maxAge: 300)
    
    employee(id: ID!): Employee @auth @cacheControl(maxAge: 300)
    
    # Finance queries
    invoices(
      filter: InvoiceFilter
      pagination: PaginationInput
      sort: SortInput
    ): InvoiceConnection @auth @cacheControl(maxAge: 120)
    
    invoice(id: ID!): Invoice @auth @cacheControl(maxAge: 120)
    
    # Inventory queries
    products(
      filter: ProductFilter
      pagination: PaginationInput
      sort: SortInput
    ): ProductConnection @auth @cacheControl(maxAge: 600)
    
    product(id: ID!): Product @auth @cacheControl(maxAge: 600)
    
    # Analytics queries
    dashboardStats: DashboardStats @auth @rateLimit(max: 10, window: "1m", message: "Too many dashboard requests")
    
    # Activity feed
    activities(
      filter: ActivityFilter
      pagination: PaginationInput
    ): ActivityConnection @auth @cacheControl(maxAge: 60)
  }

  # Root Mutation
  type Mutation {
    # User mutations
    updateProfile(input: UpdateProfileInput!): User @auth
    changePassword(input: ChangePasswordInput!): Boolean @auth
    
    # CRM mutations
    createContact(input: CreateContactInput!): Contact @auth
    updateContact(id: ID!, input: UpdateContactInput!): Contact @auth
    deleteContact(id: ID!): Boolean @auth
    
    createLead(input: CreateLeadInput!): Lead @auth
    updateLead(id: ID!, input: UpdateLeadInput!): Lead @auth
    convertLead(id: ID!, input: ConvertLeadInput!): Opportunity @auth
    
    # HRM mutations
    createEmployee(input: CreateEmployeeInput!): Employee @auth(requires: MANAGER)
    updateEmployee(id: ID!, input: UpdateEmployeeInput!): Employee @auth(requires: MANAGER)
    
    submitLeave(input: SubmitLeaveInput!): Leave @auth
    approveLeave(id: ID!, approved: Boolean!): Leave @auth(requires: MANAGER)
    
    # Finance mutations
    createInvoice(input: CreateInvoiceInput!): Invoice @auth
    updateInvoice(id: ID!, input: UpdateInvoiceInput!): Invoice @auth
    sendInvoice(id: ID!): Boolean @auth
    recordPayment(input: RecordPaymentInput!): Payment @auth
    
    # Inventory mutations
    createProduct(input: CreateProductInput!): Product @auth
    updateProduct(id: ID!, input: UpdateProductInput!): Product @auth
    adjustStock(input: AdjustStockInput!): StockMovement @auth
  }

  # Root Subscription
  type Subscription {
    # Real-time activity feed
    activityAdded(organizationId: ID!): Activity @auth
    
    # Real-time notifications
    notificationReceived(userId: ID!): Notification @auth
    
    # Live dashboard updates
    dashboardUpdated(organizationId: ID!): DashboardStats @auth
    
    # Invoice status changes
    invoiceStatusChanged(invoiceId: ID!): Invoice @auth
    
    # Lead updates
    leadUpdated(leadId: ID!): Lead @auth
  }

  # Additional types for completeness
  type Notification {
    id: ID!
    title: String!
    message: String!
    type: NotificationType!
    isRead: Boolean!
    createdAt: DateTime!
    
    user: User!
  }

  enum NotificationType {
    INFO
    SUCCESS
    WARNING
    ERROR
  }

  type DashboardStats {
    totalContacts: Int!
    totalLeads: Int!
    totalInvoices: Int!
    totalRevenue: Float!
    recentActivities: [Activity!]!
    topPerformers: [User!]!
  }

  # Input types (abbreviated for brevity)
  input ContactFilter {
    search: String
    company: String
    source: String
    assignedTo: ID
  }

  input LeadFilter {
    status: LeadStatus
    source: String
    assignedTo: ID
    dateRange: DateRangeInput
  }

  input EmployeeFilter {
    search: String
    department: ID
    status: EmployeeStatus
    manager: ID
  }

  input InvoiceFilter {
    status: InvoiceStatus
    customer: ID
    dateRange: DateRangeInput
    amountRange: AmountRangeInput
  }

  input ProductFilter {
    search: String
    category: ID
    isActive: Boolean
    lowStock: Boolean
  }

  input ActivityFilter {
    type: ActivityType
    userId: ID
    dateRange: DateRangeInput
  }

  input DateRangeInput {
    from: DateTime!
    to: DateTime!
  }

  input AmountRangeInput {
    min: Float!
    max: Float!
  }

  # Connection types
  type ContactConnection {
    edges: [ContactEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type ContactEdge {
    node: Contact!
    cursor: String!
  }

  type LeadConnection {
    edges: [LeadEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type LeadEdge {
    node: Lead!
    cursor: String!
  }

  type EmployeeConnection {
    edges: [EmployeeEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type EmployeeEdge {
    node: Employee!
    cursor: String!
  }

  type InvoiceConnection {
    edges: [InvoiceEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type InvoiceEdge {
    node: Invoice!
    cursor: String!
  }

  type ProductConnection {
    edges: [ProductEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type ProductEdge {
    node: Product!
    cursor: String!
  }

  type ActivityConnection {
    edges: [ActivityEdge!]!
    pageInfo: PageInfo!
    totalCount: Int!
  }

  type ActivityEdge {
    node: Activity!
    cursor: String!
  }

  # Input types for mutations (abbreviated)
  input UpdateProfileInput {
    firstName: String
    lastName: String
    phone: String
    bio: String
  }

  input ChangePasswordInput {
    currentPassword: String!
    newPassword: String!
  }

  input CreateContactInput {
    name: String!
    email: String
    phone: String
    company: String
    position: String
    source: String
    tags: [String!]
    customFields: JSON
  }

  input UpdateContactInput {
    name: String
    email: String
    phone: String
    company: String
    position: String
    tags: [String!]
    customFields: JSON
  }

  input CreateLeadInput {
    contactId: ID!
    title: String!
    source: String!
    value: Float
    expectedCloseDate: DateTime
    notes: String
  }

  input UpdateLeadInput {
    title: String
    status: LeadStatus
    value: Float
    probability: Int
    expectedCloseDate: DateTime
    notes: String
  }

  input ConvertLeadInput {
    title: String!
    value: Float!
    expectedCloseDate: DateTime!
    description: String
  }

  input CreateEmployeeInput {
    employeeId: String!
    firstName: String!
    lastName: String!
    email: String!
    phone: String
    position: String!
    departmentId: ID!
    managerId: ID
    hireDate: DateTime!
    salary: Float
  }

  input UpdateEmployeeInput {
    firstName: String
    lastName: String
    email: String
    phone: String
    position: String
    departmentId: ID
    managerId: ID
    salary: Float
    status: EmployeeStatus
  }

  input SubmitLeaveInput {
    type: LeaveType!
    startDate: DateTime!
    endDate: DateTime!
    reason: String
  }

  input CreateInvoiceInput {
    customerId: ID!
    issueDate: DateTime!
    dueDate: DateTime!
    currency: String!
    lineItems: [InvoiceLineItemInput!]!
    notes: String
  }

  input InvoiceLineItemInput {
    description: String!
    quantity: Int!
    unitPrice: Float!
    taxRate: Float!
    productId: ID
  }

  input UpdateInvoiceInput {
    dueDate: DateTime
    lineItems: [InvoiceLineItemInput!]
    notes: String
  }

  input RecordPaymentInput {
    invoiceId: ID!
    amount: Float!
    paymentDate: DateTime!
    method: PaymentMethod!
    reference: String
  }

  input CreateProductInput {
    sku: String!
    name: String!
    description: String
    categoryId: ID!
    price: Float!
    cost: Float
    stockQuantity: Int!
    minStockLevel: Int!
    supplierId: ID
  }

  input UpdateProductInput {
    name: String
    description: String
    categoryId: ID
    price: Float
    cost: Float
    minStockLevel: Int
    isActive: Boolean
  }

  input AdjustStockInput {
    productId: ID!
    type: MovementType!
    quantity: Int!
    reference: String
    notes: String
  }
`;

module.exports = typeDefs;