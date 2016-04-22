# SQL
various queries and useful snippets

- 1st month ever: 
outcome is a table with all subscribers' first month of using service, excluding test accounts.
Subscribers who dropped off in the past are considered new subscribers as well.
Included are only monthly subscribers.

- Customer_Churn_Analysis.sql
Analysis of Churn/Retention rate among customers who decided to purchase monthly subscription.
This query includes fixing of the data error where Subscription Start Date falls after Subscription Expiry Date in some cases.
