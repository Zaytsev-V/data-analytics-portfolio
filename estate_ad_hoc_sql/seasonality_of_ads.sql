-- Решение для Задачи 2
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- делаем сте с нужными нам полями:
stats_days AS (
    SELECT date_trunc('month', a.first_day_exposition)::date AS first_day_exp, -- переводим дату размещения в месяц
    	date_trunc('month', (a.first_day_exposition + a.days_exposition::int))::date AS last_day_exp, -- считаем дату снятия
  		a.last_price, f.total_area, a.days_exposition
	FROM real_estate.flats f
	JOIN real_estate.advertisement a USING (id)
	JOIN real_estate."type" t USING (type_id)
	WHERE id IN (SELECT * FROM filtered_id) 
		AND t."type" = 'город' -- фильтруем по условию задания
		AND (a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31') -- отсекаем хвосты 2014 и 2019 годов 
	),
-- делаем сте, группирующее предыдуший сте для активности дня публикаци, нужно будет для ранжирования
first_day_stats AS (
	SELECT first_day_exp, 
		COUNT(*) AS first_day_cnt, -- кол-во публикаций в месяц
		round(SUM(last_price)::numeric/SUM(total_area)::numeric,2) AS avg_price_m2, -- средняя цена за м2 
		round(AVG(total_area)::NUMERIC,2) AS avg_area -- средняя площадь жилья
	FROM stats_days
	GROUP BY first_day_exp 
	ORDER BY first_day_exp
	),
	-- ранжируем статистику первого размещения внутри каждого года
first_day_stats_rank AS (SELECT first_day_exp, first_day_cnt, avg_price_m2, avg_area,
	dense_rank() OVER (PARTITION BY date_trunc('year',first_day_exp)::date ORDER BY first_day_cnt DESC) AS first_rank
	FROM first_day_stats
	),
-- делаем сте, группирующее активности дня снятия, нужно будет для ранжирования
last_day_stats AS (
	SELECT last_day_exp, 
		COUNT(*) AS last_day_cnt, -- кол-во снятий
		round(SUM(last_price)::numeric/SUM(total_area)::numeric,2) AS avg_price_m2, -- средняя цена за м2 
		round(AVG(total_area)::NUMERIC,2) AS avg_area -- средняя площадь жилья
	FROM stats_days
	WHERE days_exposition IS NOT NULL 
	GROUP BY last_day_exp
	ORDER BY last_day_exp
	),
	-- ранжируем статистику снятия объявления внутри каждого года
last_day_stats_rank AS (SELECT last_day_exp, last_day_cnt, avg_price_m2, avg_area,
	dense_rank() OVER (PARTITION BY date_trunc('year',last_day_exp)::date ORDER BY last_day_cnt DESC) AS last_rank
	FROM last_day_stats
	WHERE last_day_exp <= '2018-12-31' -- учитываем интервал в 4 целых года
	)
-- Собираем данные в 1 таблицу
SELECT *
FROM first_day_stats_rank f
FULL JOIN last_day_stats_rank l ON f.first_day_exp = l.last_day_exp
ORDER BY first_day_exp;
