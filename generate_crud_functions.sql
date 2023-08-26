-- FUNCTION: public.generate_crud_functions(text)

-- DROP FUNCTION IF EXISTS public.generate_crud_functions(text);

CREATE OR REPLACE FUNCTION public.generate_crud_functions(
	p_table_name text)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    column_rec                  record;
    is_foreign_key              boolean;
    columns_definition_list     text = '';
    columns_list                text = '';
    values_list                 text = '';
    update_set_list             text = '';
    read_columns_list           text = '';
    primary_key_list            text = '';
    primary_key_condition       text = '';
    primary_key_definition_list text = '';
    create_function_script      text;
    read_function_script        text;
    delete_function_script      text;
    update_function_script      text;
BEGIN
    -- Identify the primary keys and build the WHERE condition
    FOR column_rec IN (SELECT k.column_name, c.data_type
                       FROM information_schema.table_constraints tc
                                JOIN information_schema.key_column_usage k ON tc.constraint_name = k.constraint_name
                                JOIN information_schema.columns c
                                     ON c.column_name = k.column_name AND c.table_name = k.table_name
                       WHERE tc.table_name = p_table_name
                         AND tc.constraint_type = 'PRIMARY KEY'
                       ORDER BY k.ordinal_position)
    LOOP
        IF primary_key_list <> '' THEN
            primary_key_list := primary_key_list || ', ';
            primary_key_condition := primary_key_condition || ' AND ';
            primary_key_definition_list := primary_key_definition_list || ', ';
        END IF;

        primary_key_list := primary_key_list || column_rec.column_name;
        primary_key_condition := primary_key_condition || p_table_name || '.' || column_rec.column_name ||
                                 ' = p_' || column_rec.column_name;
        primary_key_definition_list := primary_key_definition_list || 'p_' || column_rec.column_name || ' ' ||
                                       column_rec.data_type;
    END LOOP;

    -- Fetch all columns and their types based on ordinal position
    FOR column_rec IN (SELECT column_name, data_type, column_default
                       FROM information_schema.columns
                       WHERE table_name = p_table_name
                       ORDER BY ordinal_position)
    LOOP
        RAISE NOTICE 'Processing column % with type %', column_rec.column_name, column_rec.data_type;

        -- Check if the column is a foreign key
        SELECT EXISTS (SELECT 1
                       FROM information_schema.key_column_usage kcu
                                JOIN information_schema.referential_constraints rc
                                     ON kcu.constraint_name = rc.constraint_name
                       WHERE kcu.table_name = p_table_name
                         AND kcu.column_name = column_rec.column_name)
        INTO is_foreign_key;

        -- Append to columns list
        columns_list := columns_list || column_rec.column_name || ', ';

        -- Append to read columns list
        read_columns_list := read_columns_list || column_rec.column_name || ' ' || column_rec.data_type || ', ';

        -- Handle the insertion values
        IF column_rec.column_name IN ('created_at', 'updated_at') THEN
            values_list := values_list || 'now(), ';
        ELSIF column_rec.data_type = 'uuid' AND NOT is_foreign_key AND column_rec.column_default IS NOT NULL THEN
            values_list := values_list || 'uuid_generate_v4(), ';
        ELSIF column_rec.data_type = 'uuid' THEN
            columns_definition_list := columns_definition_list || 'v_' || column_rec.column_name || ' uuid, ';
            values_list := values_list || 'v_' || column_rec.column_name || ', ';
        ELSIF column_rec.column_default IS NOT NULL THEN
            values_list := values_list || 'DEFAULT, ';
        ELSE
            columns_definition_list := columns_definition_list || 'v_' || column_rec.column_name || ' ' ||
                                       column_rec.data_type || ', ';
            values_list := values_list || 'v_' || column_rec.column_name || ', ';
        END IF;

        -- Update set list
        IF position(column_rec.column_name in primary_key_list) = 0 AND column_rec.column_name <> 'created_at' THEN
            IF column_rec.column_name = 'updated_at' THEN
                update_set_list := update_set_list || 'updated_at = now(), ';
            ELSE
                update_set_list := update_set_list || column_rec.column_name || ' = ' ||
                                   'v_' || column_rec.column_name || ', ';
            END IF;
        END IF;
    END LOOP;

    -- Trim trailing commas
    columns_list := trim(trailing ', ' from columns_list);
    columns_definition_list := trim(trailing ', ' from columns_definition_list);
    values_list := trim(trailing ', ' from values_list);
    update_set_list := trim(trailing ', ' from update_set_list);
    read_columns_list := trim(trailing ', ' from read_columns_list);

    -- 1. Create Function script
    create_function_script := format('
        CREATE OR REPLACE FUNCTION %1$s_create(%2$s)
        RETURNS void AS $func$
        BEGIN
            INSERT INTO %1$s(%3$s) VALUES(%4$s);
        END;
        $func$ LANGUAGE plpgsql;
    ', p_table_name, columns_definition_list, columns_list, values_list);

    -- 2. Read Function script
    read_function_script := format('
        CREATE OR REPLACE FUNCTION %1$s_read(%2$s)
        RETURNS TABLE (%3$s) AS $func$
        BEGIN
            RETURN QUERY SELECT * FROM %1$s WHERE %4$s;
        END;
        $func$ LANGUAGE plpgsql;
    ', p_table_name, primary_key_definition_list, read_columns_list, primary_key_condition);

    -- 3. Update Function script
    update_function_script := format('
        CREATE OR REPLACE FUNCTION %1$s_update(%2$s, %3$s)
        RETURNS void AS $func$
        BEGIN
            UPDATE %1$s SET %5$s WHERE %4$s;
        END;
        $func$ LANGUAGE plpgsql;
    ', p_table_name, primary_key_definition_list, columns_definition_list, primary_key_condition, update_set_list);

    -- 4. Delete Function script
    delete_function_script := format('
        CREATE OR REPLACE FUNCTION %1$s_delete(%2$s)
        RETURNS void AS $func$
        BEGIN
            DELETE FROM %1$s WHERE %3$s;
        END;
        $func$ LANGUAGE plpgsql;
    ', p_table_name, primary_key_definition_list, primary_key_condition);

    EXECUTE create_function_script;
    EXECUTE read_function_script;
    EXECUTE update_function_script;
    EXECUTE delete_function_script;
END;
$BODY$;

ALTER FUNCTION public.generate_crud_functions(text)
    OWNER TO [your_username];
