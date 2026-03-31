# CarCosts

CarCosts is an iOS app for tracking the true per-kilometre cost of owning a car. It combines fuel tracking, recurring expenses, one-time costs, and vehicle depreciation into a single cost-per-kilometre figure, updated in real time as you log data.

Built with SwiftUI and SwiftData, targeting iOS 26.

---

## Features

### Cost per kilometre

The core calculation combines four cost streams:

- **Fuel** — total spend on fill-ups divided by kilometres driven
- **Recurring costs** — monthly expenses (insurance, road tax, subscriptions) pro-rated for the selected period
- **One-time costs** — repairs, tyres, parking, tolls, and other individual expenses
- **Amortisation** — vehicle depreciation in EUR/km, derived from purchase price minus current resale value divided by total kilometres driven

The app shows both a fuel-only figure and a total figure so you can separate running costs from the full ownership cost.

### Fuel tracking

Each fill-up records date, odometer reading, litres, total cost, and price per litre. The entry form calculates the third value automatically once you finish entering any two — you tap away from a field when done, and the missing value fills in.

Fill-ups can be marked as full-tank or partial. Fuel efficiency (L/100km) uses the full-tank method: measurements are only taken between consecutive full-tank entries, with any partial fill-ups in between contributing their litres to the segment. This prevents partial top-ups from distorting efficiency figures.

### Cost categories

One-time and recurring costs each belong to one of eight categories: Insurance, Road Tax, Maintenance, Cosmetic, Repair, Parking, Toll, Other. Categories carry colour-coded icons throughout the app.

Recurring costs have a start date and optional end date, allowing you to track subscriptions that begin or end mid-period. Costs are pro-rated for partial months.

### Amortisation and resale value

Recording a resale estimate unlocks the amortisation tracking. The app shows EUR/km of depreciation, the total value lost since purchase, and incorporates depreciation into the total cost-per-km figure.

A configurable reminder prompts you to update the resale value on a monthly, yearly, or never schedule. The prompt appears as a dismissible banner on the dashboard when due.

### Periods and date ranges

The dashboard and stats screen both support three period modes: This Month, All Time, and a custom date range with From/To pickers. All calculations update instantly when the period changes.

### Stats and charts

The stats screen shows:

- A summary grid with total spend, distance, fuel cost, recurring costs, other costs, and amortisation for the selected period
- A bar chart of monthly fuel spending over the last 12 months
- A line chart of fuel efficiency per full-tank segment
- A donut chart breaking down costs by type (fuel, amortisation, recurring, other)

### Logs

The logs screen shows all fuel entries and costs in two tabs. Fuel entries display litres, price per litre, odometer, kilometres since the previous fill-up, efficiency where calculable, and total cost. Cost entries show category, name, amount, date, and any notes. All entries support editing and deletion.

---

## Screens

### Dashboard

The main screen at a glance. Shows fuel-only and total cost-per-km for the selected period, a stats badge row with distance, efficiency, and fuel spend, an amortisation card when resale data exists, and the five most recent log entries. A floating action button opens the fill-up form directly.

### Logs

Full history of all fuel fill-ups and costs. Fuel and costs are separated into tabs. The fuel tab shows efficiency data per entry where the full-tank method can compute it. The costs tab separates recurring and one-time entries.

### Stats

Historical trends as charts. Covers monthly fuel spending, per-segment fuel efficiency over time, and cost breakdown by category.

### Settings

Car configuration, resale value history, recurring cost management, and the resale value reminder schedule. The car name, purchase price, initial odometer, and purchase date can all be edited after initial setup.

---

## Onboarding

On first launch, the app asks for a car name, purchase price, optional initial odometer reading, and purchase date. The initial odometer is used as the baseline for distance calculations before any fill-ups are logged.

---

## Data model

| Entity | Key fields |
|---|---|
| Car | name, purchasePrice, purchaseDate, initialOdometer |
| FuelEntry | date, liters, totalCost, pricePerLiter, odometerReading, filledToFull |
| ResaleValueEntry | date, value |
| RecurringCost | name, monthlyAmount, startDate, endDate, category |
| OtherCost | name, amount, date, category, notes |

All relationships cascade on delete. The schema uses SwiftData with a versioned migration plan.

---

## Requirements

- iOS 26
- Xcode 26
