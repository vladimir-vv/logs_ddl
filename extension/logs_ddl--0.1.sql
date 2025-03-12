
\echo
CREATE TABLE @extschema@.logs (
  id bigint NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  creation_date timestamp with time zone DEFAULT now() NOT NULL,
  command_tag text,
  object_type text,
  schema_name text,
  object_identity text,
  in_extension boolean,
  tg_event text,
  tg_tag text,
  username text,
  client_addr inet,
  query_text text,
  classid oid,
  objid oid,
  object text,
  object_def text
);
CREATE INDEX ON @extschema@.logs USING btree (creation_date);

CREATE TABLE @extschema@.skip_rules (
  type_id int NOT NULL,
  rule varchar(64) NOT NULL,
  CONSTRAINT skip_rules_pkey PRIMARY KEY (type_id, rule)
);
COMMENT ON COLUMN @extschema@.skip_rules.type_id IS '1 - schema_name
2 - command_tag
3 - current_query (regexp)';

INSERT INTO @extschema@.skip_rules VALUES (1, 'pg_temp');
INSERT INTO @extschema@.skip_rules VALUES (1, 'repack');
INSERT INTO @extschema@.skip_rules VALUES (2, 'REFRESH MATERIALIZED VIEW');

SELECT pg_catalog.pg_extension_config_dump('@extschema@.skip_rules', '');


CREATE OR REPLACE FUNCTION @extschema@.write_ddl()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
 v_obj record;
 v_save_obj text:=NULL;
 v_save_obj_def text:=NULL;
BEGIN
  FOR v_obj IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF (NOT EXISTS (SELECT 1 FROM @extschema@.skip_rules WHERE type_id=1 AND rule=v_obj.schema_name)
        AND NOT EXISTS (SELECT 1 FROM @extschema@.skip_rules WHERE type_id=2 AND rule=v_obj.command_tag)
			 ) THEN
      CASE (SELECT relname FROM pg_class WHERE oid=v_obj.classid)
        WHEN 'pg_proc' THEN
          SELECT INTO v_save_obj row_to_json(q1)::text FROM (SELECT * FROM pg_proc WHERE oid=v_obj.objid) q1;
          IF v_obj.object_type = 'function' THEN
            v_save_obj_def = pg_get_functiondef(v_obj.objid);
          END IF;
        WHEN 'pg_class' THEN
          SELECT INTO v_save_obj row_to_json(q1)::text FROM (SELECT * FROM pg_class WHERE oid=v_obj.objid) q1;
          IF v_obj.object_type = 'view' THEN
            v_save_obj_def = pg_get_viewdef(v_obj.objid);
          END IF;
        ELSE
      END CASE;
      INSERT INTO @extschema@.logs(command_tag, object_type, schema_name, object_identity, in_extension,
        tg_event, tg_tag, username, client_addr, query_text, classid, objid, object, object_def)
      VALUES(v_obj.command_tag, v_obj.object_type, v_obj.schema_name, v_obj.object_identity, v_obj.in_extension,
        TG_EVENT, TG_TAG, SESSION_USER::text, inet_client_addr(), current_query(),
        v_obj.classid, v_obj.objid, v_save_obj, v_save_obj_def);
    END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION @extschema@.write_drop()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
 v_obj record;
BEGIN
  FOR v_obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF (NOT EXISTS (SELECT 1 FROM @extschema@.skip_rules WHERE type_id=1 AND rule=v_obj.schema_name)) THEN
      INSERT INTO @extschema@.logs(command_tag, object_type, schema_name, object_identity, in_extension,
        tg_event, tg_tag, username, client_addr, query_text)
      VALUES('DROP', v_obj.object_type, v_obj.schema_name, v_obj.object_identity, false,
        TG_EVENT, TG_TAG, current_user::text, inet_client_addr(), current_query() );
    END IF;
  END LOOP;
END;
$function$;

CREATE EVENT TRIGGER @extschema@_ddl ON ddl_command_end EXECUTE FUNCTION @extschema@.write_ddl();

CREATE EVENT TRIGGER @extschema@_drop ON sql_drop EXECUTE FUNCTION @extschema@.write_drop();
