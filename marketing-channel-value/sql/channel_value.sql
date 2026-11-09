-- =====================================================================
-- Case Study: Where should the next marketing dollar go?
-- Dataset: Maven Toy Store (schema: toystore)
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Channel performance (last 12 months: 2014-03-01 -> 2015-03-01)
-- ---------------------------------------------------------------------
-- What it does: Groups every session into a marketing channel and shows
-- how many sessions and orders each channel brought, the conversion rate,
-- and how much gross margin (price - cost - refunds) each session earned.
--
-- Why it matters: "margin_per_session" is the most a paid channel can pay
-- per click and still break even (break-even CPC). If a channel's real
-- cost per click is above this number, it loses money.
--
-- Channel rules:
--   utm_source filled            -> paid channel (source + campaign)
--   utm_source empty, referer set -> organic search (free)
--   both empty                   -> direct type-in (free)
-- ---------------------------------------------------------------------
WITH sess AS (
    SELECT
        website_session_id,
        CASE
            WHEN utm_source IS NOT NULL   THEN utm_source || ' ' || utm_campaign
            WHEN http_referer IS NOT NULL THEN 'organic search'
            ELSE 'direct type-in'
        END AS channel
    FROM toystore.website_sessions
    WHERE created_at >= '2014-03-01'
      AND created_at <  '2015-03-01'
),
refunds AS (
    SELECT order_id, SUM(refund_amount_usd) AS refund_usd
    FROM toystore.order_item_refunds
    GROUP BY order_id
)
SELECT
    s.channel,
    COUNT(*)                                                       AS sessions,
    COUNT(o.order_id)                                              AS orders,
    ROUND(100.0 * COUNT(o.order_id) / COUNT(*), 2)                 AS cvr_pct,
    ROUND(SUM(o.price_usd - COALESCE(r.refund_usd, 0)), 0)         AS net_revenue,
    ROUND(SUM(o.price_usd - o.cogs_usd - COALESCE(r.refund_usd, 0))
          / COUNT(*), 2)                                           AS margin_per_session
FROM sess s
LEFT JOIN toystore.orders o ON o.website_session_id = s.website_session_id
LEFT JOIN refunds r         ON r.order_id = o.order_id
GROUP BY s.channel
ORDER BY sessions DESC;


-- ---------------------------------------------------------------------
-- Q2. Customer value by first-touch channel
-- ---------------------------------------------------------------------
-- What it does: Finds the channel that brought each visitor for the FIRST
-- time, then follows those visitors forward: did they come back, and how
-- many orders / how much margin did they generate in total (first visit
-- + every return visit)?
--
-- Why it matters: Q1 only credits the session that placed the order.
-- If paid search brings a visitor who later returns for free and buys,
-- Q1 gives that sale to "direct" or "organic". Q2 gives it back to the
-- channel that found the customer.
--
-- Window: first visits between 2014-03-01 and 2014-09-01, so every user
-- has at least ~6 months of follow-up before the data ends.
-- ---------------------------------------------------------------------
WITH sess AS (
    SELECT
        website_session_id,
        user_id,
        is_repeat_session,
        created_at,
        CASE
            WHEN utm_source IS NOT NULL   THEN utm_source || ' ' || utm_campaign
            WHEN http_referer IS NOT NULL THEN 'organic search'
            ELSE 'direct type-in'
        END AS channel
    FROM toystore.website_sessions
),
first_touch AS (
    SELECT user_id, channel AS first_channel
    FROM sess
    WHERE is_repeat_session = 0
      AND created_at >= '2014-03-01'
      AND created_at <  '2014-09-01'
),
user_returns AS (
    SELECT user_id, COUNT(*) AS repeat_sessions
    FROM sess
    WHERE is_repeat_session = 1
    GROUP BY user_id
),
user_orders AS (
    SELECT user_id,
           COUNT(*)                    AS orders,
           SUM(price_usd - cogs_usd)   AS margin_usd
    FROM toystore.orders
    GROUP BY user_id
)
SELECT
    f.first_channel,
    COUNT(*)                                                         AS users,
    ROUND(100.0 * COUNT(ur.user_id) / COUNT(*), 1)                   AS pct_returned,
    ROUND(100.0 * SUM(COALESCE(uo.orders, 0)) / COUNT(*), 2)         AS orders_per_100_users,
    ROUND(SUM(COALESCE(uo.margin_usd, 0)) / COUNT(*), 2)             AS margin_per_user
FROM first_touch f
LEFT JOIN user_returns ur ON ur.user_id = f.user_id
LEFT JOIN user_orders  uo ON uo.user_id = f.user_id
GROUP BY f.first_channel
ORDER BY users DESC;


-- ---------------------------------------------------------------------
-- Q3. Budget shift scenario: socialbook -> bsearch nonbrand
-- ---------------------------------------------------------------------
-- What it does: Takes the margin each channel earned in Q1, then asks:
-- "If the sessions we bought on socialbook had earned what bsearch
-- nonbrand earns per session, how much more margin would we have made?"
--
-- Why it matters: This turns the Q1 gap into a dollar number for the
-- recommendation. Assumption: the same number of paid sessions can be
-- bought on bsearch nonbrand at a similar cost per click (the dataset has
-- no ad spend), so the result is a ceiling to test, not a promise.
-- ---------------------------------------------------------------------
WITH sess AS (
    SELECT
        website_session_id,
        CASE
            WHEN utm_source IS NOT NULL   THEN utm_source || ' ' || utm_campaign
            WHEN http_referer IS NOT NULL THEN 'organic search'
            ELSE 'direct type-in'
        END AS channel
    FROM toystore.website_sessions
    WHERE created_at >= '2014-03-01'
      AND created_at <  '2015-03-01'
),
refunds AS (
    SELECT order_id, SUM(refund_amount_usd) AS refund_usd
    FROM toystore.order_item_refunds
    GROUP BY order_id
),
channel_margin AS (
    SELECT
        s.channel,
        COUNT(*) AS sessions,
        SUM(COALESCE(o.price_usd - o.cogs_usd - COALESCE(r.refund_usd, 0), 0)) AS margin_usd
    FROM sess s
    LEFT JOIN toystore.orders o ON o.website_session_id = s.website_session_id
    LEFT JOIN refunds r         ON r.order_id = o.order_id
    GROUP BY s.channel
),
target AS (
    SELECT margin_usd / sessions AS margin_per_session
    FROM channel_margin
    WHERE channel = 'bsearch nonbrand'
)
SELECT
    SUM(c.sessions)                                         AS social_sessions,
    ROUND(SUM(c.margin_usd), 0)                             AS current_margin,
    ROUND(SUM(c.sessions) * MAX(t.margin_per_session), 0)   AS margin_if_bsearch,
    ROUND(SUM(c.sessions) * MAX(t.margin_per_session)
          - SUM(c.margin_usd), 0)                           AS extra_margin
FROM channel_margin c
CROSS JOIN target t
WHERE c.channel LIKE 'socialbook%';
