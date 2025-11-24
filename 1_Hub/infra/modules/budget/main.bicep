targetScope = 'subscription'

@description('Monthly budget amount in USD')
param subscriptionBudgetAmount int = 200

@description('Start date for the budget in ISO 8601 format')
param budgetStartDate string = '2025-01-01T00:00:00Z'

@description('Contact email addresses for budget alerts (optional - budget will be disabled if empty)')
param budgetContactEmails array = []

@description('Enable budget monitoring')
param enableBudget bool = !empty(budgetContactEmails)

resource budgetSub 'Microsoft.Consumption/budgets@2021-10-01' = if (enableBudget) {
  name: 'subscription-monthly'
  properties: {
    category: 'Cost'
    amount: subscriptionBudgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      Actual_GreaterThan_80_Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: budgetContactEmails
        thresholdType: 'Actual'
      }
      Actual_GreaterThan_100_Percent: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: budgetContactEmails
        thresholdType: 'Actual'
      }
    }
  }
}
