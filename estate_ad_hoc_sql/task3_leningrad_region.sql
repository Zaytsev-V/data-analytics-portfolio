--Задача 3.
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
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выводим нужные для задачи поля
SELECT c.city, t."type", COUNT(*) AS exp_cnt, -- кол-во объявлений
	COUNT(*) FILTER (WHERE a.days_exposition IS NOT NULL) AS removed_exp_cnt, -- кол-во снятых объявлений
	round((COUNT(*) FILTER (WHERE a.days_exposition IS NOT NULL))::NUMERIC/COUNT(*),2) AS removed_exp_share, -- доля снятых объявлений
	round(AVG(a.days_exposition)) AS avg_activ_days, -- среднее кол-во дней активации
	round((SUM(last_price)/SUM(total_area))::numeric,2) AS avg_price_m2, -- средняя цена м2
	round(AVG(total_area)::numeric,2) AS avg_total_area, -- средняя площадь помещения
	round(AVG(last_price)) AS avg_total_price, -- средняя стоимость жилья
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median, -- медиана кол-ва комнат
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_median, -- медиана кол-ва балконов
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS floor_midian -- медиана этажности
FROM real_estate.flats f
INNER JOIN real_estate.advertisement AS a USING(id)
INNER JOIN real_estate.city AS c USING(city_id)
INNER JOIN real_estate."type" AS t USING(type_id)
WHERE id IN (SELECT * FROM filtered_id) AND c.city != 'Санкт-Петербург'
GROUP BY c.city, t."type"
ORDER BY exp_cnt DESC
LIMIT 15;
