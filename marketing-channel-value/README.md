# Where Should the Next Marketing Dollar Go?

**Dataset:** Maven Toy Store e-commerce data (website sessions, orders, refunds), Mar 2014 – Mar 2015
**Tools:** SQL (PostgreSQL)

## Problem

The marketing team buys traffic from paid search (gsearch, bsearch) and a social channel (socialbook). The data has no ad spend, so the question is: **how much is one visit from each channel actually worth, and which channel deserves less budget?**

## Findings

1. **Search pays ~$2.85–3.66 per visit; social pays $0.48–1.94.** Order value is the same everywhere (~$61). The gap comes only from conversion: search converts at 7.5–9.6%, socialbook desktop_targeted at 5.2% and the socialbook pilot at 1.1%.
2. **Return visits don't change the picture.** About 15% of new visitors come back in every channel. Counting all later visits, a visitor first brought by search is worth ~$3.5–4.4, a visitor from socialbook ~$1.4–2.1.
3. **Social is small but clearly the weakest spend.** It brings 2.7% of sessions and 1.6% of gross margin.

![Break-even CPC by channel](images/chart1_break_even_cpc.png)
![Value per new visitor by first channel](images/chart2_value_per_customer.png)

## Financial Impact

socialbook brought **6,830 sessions** that earned **$11.4k** in gross margin. The same number of sessions at bsearch nonbrand's margin per visit would earn **$19.9k**: **+$8.5k a year (+74%)** on that budget.

![Budget shift scenario](images/chart3_reallocation_scenario.png)

## Recommendation

1. **Stop the socialbook pilot.** A visit earns $0.48, about one-sixth of what a search visit earns.
2. **Cap socialbook desktop_targeted bids at $1.94 per click** (its break-even point), or pause it.
3. **Move the freed budget to bsearch nonbrand** and test it for 4–6 weeks. It earns the same per visit as gsearch nonbrand but gets 5× fewer sessions, so it likely has room to grow.
4. **Use margin per session as the bid ceiling** for every paid channel going forward.

## Assumptions & Limits

- No ad spend in the data, so channels are judged by **break-even CPC** (gross margin per session) instead of an assumed cost. One session ≈ one paid click.
- The scenario assumes bsearch nonbrand can absorb ~6.8k more sessions at a similar cost per click. Bigger budgets usually mean higher CPCs, so +$8.5k is a ceiling to test, not a promise.
- Gross margin = price − product cost − refunds (refunds are not subtracted in the per-visitor view).

---

Queries: [`sql/channel_value.sql`](sql/channel_value.sql)
