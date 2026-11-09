-- Where should the next marketing dollar go?
-- Maven Toy Store data, schema: toystore

-- Q1. Channel performance (Mar 2014 - Mar 2015)
-- Sessions, orders, conversion rate and gross margin per session for each channel.
-- Margin per session = the most we can pay for one click without losing money (break-even CPC).
-- Channels: utm_source filled = paid, only http_referer filled = organic search, both empty = direct.
-- LEFT JOIN keeps sessions without an order, so conversion rate is correct.
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


-- Q2. Value per new visitor, by the channel of their first visit
-- Q1 gives the order to the session that placed it. But a visitor can come from paid search
-- first and buy later from direct or organic. Q2 gives all their orders to their first channel.
-- Only first visits from Mar - Aug 2014, so every visitor has at least 6 months to come back.
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


-- Q3. What if the social sessions earned like bsearch nonbrand?
-- Current social margin vs. the same number of sessions at bsearch nonbrand's margin per session.
-- Assumption: we can buy the same number of sessions on bsearch nonbrand at a similar cost per click.
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
