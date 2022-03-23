CREATE SCHEMA IF NOT EXISTS garden;
COMMENT ON SCHEMA garden IS 'A simple garden log.';


CREATE TABLE IF NOT EXISTS garden.actions (
	action   SERIAL NOT NULL PRIMARY KEY,
	label    TEXT,
	UNIQUE (label)
);
COMMENT ON TABLE garden.actions IS
'Things you can do in the garden.';

INSERT INTO garden.actions (label) VALUES
('sow'),('pot'),('plant'),('harvest')
ON CONFLICT (label) DO NOTHING;


CREATE TABLE IF NOT EXISTS garden.beds (
	bed     SERIAL NOT NULL PRIMARY KEY,
	id      TEXT UNIQUE,
	label   TEXT UNIQUE
);
COMMENT ON TABLE garden.beds IS
'Places you can perform actions in the garden.';


CREATE TABLE IF NOT EXISTS garden.plants (
	plant   SERIAL NOT NULL PRIMARY KEY,
	label   TEXT,
	UNIQUE (label)
);
COMMENT ON TABLE garden.plants IS
'Plants you can perform actions with.';


CREATE TABLE IF NOT EXISTS garden.varieties (
	variety   SERIAL NOT NULL PRIMARY KEY,
	plant     INTEGER REFERENCES garden.plants(plant),
	label     TEXT,
	UNIQUE (plant, label)
);
COMMENT ON TABLE garden.varieties IS
'Types of plants.';


CREATE TABLE IF NOT EXISTS garden.ledger (
	ts          TIMESTAMPTZ NOT NULL DEFAULT date_trunc('minute',CURRENT_TIMESTAMP),
	action      INTEGER REFERENCES garden.actions(action) NOT NULL,
	plant       INTEGER REFERENCES garden.plants(plant) NOT NULL,
	variety     INTEGER REFERENCES garden.varieties(variety) DEFAULT NULL,
	bed         INTEGER REFERENCES garden.beds(bed) DEFAULT NULL,
	quantity    INTEGER DEFAULT NULL,
	weight_oz   INTEGER DEFAULT NULL
) PARTITION BY RANGE (ts);
COMMENT ON TABLE garden.ledger IS
'Fact table of garden history.';


CREATE OR REPLACE VIEW garden.log AS
SELECT
	ts,
	CASE WHEN lag(ts::date) OVER (ORDER BY ts DESC) = ts::date THEN
	NULL ELSE to_char(date_trunc('day',ts),'Month DD YYYY') END AS date,

	/* "Actioned ammount plant in bed" */
	format('%1$sed %2$s%3$s%4$s',
		a.label,

		CASE WHEN l.weight_oz IS NOT NULL AND a.label = 'harvest' THEN
			(l.weight_oz/16)::TEXT || ' pounds ' ||
			(MOD(l.weight_oz, 16))::TEXT || ' ounces '
		WHEN l.quantity > 0 THEN l.quantity || ' ' ELSE '' END,

		CASE WHEN v.label IS NOT NULL THEN v.label ||' '|| p.label
		ELSE p.label END,

		CASE WHEN b.label IS NOT NULL THEN ' in ' || b.label ELSE '' END

	) AS action
FROM garden.ledger l
JOIN garden.actions a USING (action)
JOIN garden.plants p USING (plant)
LEFT JOIN garden.varieties v USING (variety)
LEFT JOIN garden.beds b USING (bed);
COMMENT ON VIEW garden.log IS
'Human readable version of the garden ledger.';


CREATE OR REPLACE FUNCTION garden.add_entry(
	fact   JSONB,
	ts     TIMESTAMPTZ DEFAULT date_trunc('minute',CURRENT_TIMESTAMP)
)
RETURNS BOOLEAN AS $$
DECLARE
	need_to_part   BOOLEAN;
	action         INTEGER;
	plant          INTEGER;
	quantity       INTEGER;
	variety        INTEGER;
	weight         INTEGER;
	bed            INTEGER;
BEGIN

	/* Fetch FKs for dimension TABLEs adding new entries if needed. */
	IF NOT ($1 ? 'action') THEN
		RAISE EXCEPTION 'An action is required';
	END IF;

	WITH input (action) AS (
		VALUES ($1->>'action')
	), upsert AS (
		INSERT INTO garden.actions (label)
		SELECT i.action FROM input i
		ON CONFLICT (label) DO NOTHING RETURNING garden.actions.action
	)
	SELECT u.action FROM upsert u
	UNION ALL
	SELECT a.action FROM input i
	JOIN garden.actions a ON i.action = a.label
	INTO action;

	IF NOT ($1 ? 'plant') THEN
		RAISE EXCEPTION 'A plant is required';
	END IF;

	WITH input (plant) AS (
		VALUES ($1->>'plant')
	), upsert AS (
		INSERT INTO garden.plants (label)
		SELECT i.plant FROM input i
		ON CONFLICT (label) DO NOTHING RETURNING garden.plants.plant
	)
	SELECT u.plant FROM upsert u
	UNION ALL
	SELECT a.plant FROM input i
	JOIN garden.plants a ON i.plant = a.label
	INTO plant;

	/* Variety can be optional */
	IF $1 ? 'variety' AND NOT $1->>'variety' = '' THEN
		WITH input (plant, variety) AS (
			VALUES (plant, LOWER($1->>'variety'))
		), upsert AS (
			INSERT INTO garden.varieties (plant, label)
			SELECT i.plant, i.variety FROM input i
			ON CONFLICT ON CONSTRAINT varieties_plant_label_key
			DO NOTHING RETURNING garden.varieties.variety
		)
		SELECT u.variety FROM upsert u
		UNION ALL
		SELECT a.variety FROM input i
		JOIN garden.varieties a ON i.variety = a.label
		INTO variety;
	END IF;

	/* Bed can be optional */
	IF $1 ? 'bed' AND NOT $1->>'bed' = '' THEN
	WITH input (bed) AS (
		VALUES ($1->>'bed')
	), upsert AS (
		INSERT INTO garden.beds (label)
		SELECT i.bed FROM input i
		ON CONFLICT (label) DO NOTHING RETURNING garden.beds.bed
	)
	SELECT u.bed FROM upsert u
	UNION ALL
	SELECT a.bed FROM input i
	JOIN garden.beds a ON i.bed = a.label
	INTO bed;
	END IF;

	/* Quantity can be optional */
	IF $1 ? 'quantity' AND NOT $1->>'quantity' = '' THEN
		SELECT ($1->>'quantity')::INTEGER INTO quantity;
	END IF;

	/* Weight can be optional */
	IF $1 ? 'weight' AND NOT $1->>'weight' = '' THEN
		SELECT ($1->>'weight')::INTEGER INTO weight;
	END IF;

	/*
	 * INSERT into the garden ledger creating a new PARTITION if needed.
	 */
	need_to_part := true;
	LOOP
		BEGIN
			INSERT INTO garden.ledger (
				action, plant, variety, bed, quantity, weight_oz, ts
			) VALUES (
				action, plant, variety, bed, quantity, weight, $2
			);

			need_to_part := false;
			EXIT;

		EXCEPTION WHEN check_violation THEN END;

		IF need_to_part THEN
			EXECUTE format('	
				CREATE TABLE IF NOT EXISTS garden.ledger_%1$s
				PARTITION OF garden.ledger 
				FOR VALUES FROM (''%2$s'') TO (''%3$s'')
			',to_char(date_trunc('year',$2),'YYYY'),
			date_trunc('year',$2),
			date_trunc('year',$2) + '1 year'::interval);
		END IF;
	
	END LOOP;

	RETURN true;
END
$$ LANGUAGE PLPGSQL;
COMMENT ON FUNCTION garden.add_entry IS
'Log an ''action'' with a ''plant'' in garden.ledger.  ''bed'' and ''variety'' are optional.';
