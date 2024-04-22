#!/bin/bash

# Installing yq
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Installing yaml query on the server.
===============================================================================================================================================================================  \e[39m"
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 || true
sudo chmod a+x /usr/local/bin/yq || true
yq --version || true

# Stopping sharder container
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Stop sharder container on the server.
===============================================================================================================================================================================  \e[39m"
docker stop sharder-1

# Stopping 0chain.yaml config
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            updating 0chain.yaml config.
===============================================================================================================================================================================  \e[39m"
yq e -i '.server_chain.dbs.settings.permanent_partition_change_period = 2000000' /var/0chain/sharder/ssd/docker.local/config/0chain.yaml
yq e -i '.server_chain.dbs.settings.permanent_partition_keep_count = 1' /var/0chain/sharder/ssd/docker.local/config/0chain.yaml

# Creating script to be executed on the sharder postgres
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Creating script for postgres.
===============================================================================================================================================================================  \e[39m"
docker exec sharder-postgres-1 psql -U zchain_user -d events_db -c """CREATE OR REPLACE FUNCTION public.create_partition_tables(
	schema_name text,
	base_table_name text,
	partition_column text,
	interval_size integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS \$BODY\$
DECLARE
    min_value int;
    max_value int;
    start_value int;
    end_value int;
    new_table_name text;
    old_table_name text;
    create_table_stmt text;
    insert_data_stmt text;
    rename_table_stmt text;
	reatach_seq_stmt text;
	drop_base_table_stmt text;
BEGIN
    -- Get the minimum and maximum values from the base table
    EXECUTE 'SELECT MIN(' || partition_column || '), MAX(' || partition_column || ') FROM ' || schema_name || '.' || base_table_name INTO min_value, max_value;

    start_value := 0;

    -- Generate new partitioned table name
    new_table_name := base_table_name || '_new';

    -- Create new partitioned table based on the existing partitioned table structure
    create_table_stmt := 'CREATE TABLE ' || schema_name || '.' || new_table_name || ' (LIKE ' || schema_name || '.' || base_table_name || ' INCLUDING ALL) PARTITION BY RANGE (' || partition_column || ');';
    EXECUTE create_table_stmt;

    -- Rename the old table
    old_table_name := base_table_name || '_old';
    rename_table_stmt := 'ALTER TABLE ' || schema_name || '.' || base_table_name || ' RENAME TO ' || old_table_name || ';';
    EXECUTE rename_table_stmt;

    -- Loop through each partition, create it, and attach it to the new table
    WHILE start_value <= max_value LOOP
        end_value := start_value + interval_size;

        -- Check if the calculated end_value exceeds the max_value
        IF end_value > max_value THEN
            end_value := max_value;
        END IF;

		IF end_value = max_value THEN
            end_value := start_value + interval_size ;
        END IF;
        -- Generate partition name
        DECLARE
            partition_name text := base_table_name || '_part_' || start_value || '_' || end_value ;
        BEGIN
            -- Create the partition as a partition of the new table
            create_table_stmt := 'CREATE TABLE ' || schema_name || '.' || partition_name || ' PARTITION OF ' || schema_name || '.' || new_table_name || ' FOR VALUES FROM (' || start_value || ') TO (' || end_value || ');';
            EXECUTE create_table_stmt;

            -- Insert data into the partition from the old table
            insert_data_stmt := 'INSERT INTO ' || schema_name || '.' || partition_name || ' SELECT * FROM ' || schema_name || '.' || old_table_name || ' WHERE ' || partition_column || ' BETWEEN ' || start_value || ' AND ' || end_value -1 || ';';
            EXECUTE insert_data_stmt;
        END;

        start_value := end_value;
    END LOOP;

    -- Rename the new table to match the original table name
    rename_table_stmt := 'ALTER TABLE ' || schema_name || '.' || new_table_name || ' RENAME TO ' || base_table_name || ';';
    EXECUTE rename_table_stmt;

	reatach_seq_stmt := 'ALTER SEQUENCE ' || schema_name || '.' || base_table_name || '_id_seq' || ' OWNED BY ' ||schema_name || '.'  || base_table_name || '.id' || ';';
    EXECUTE reatach_seq_stmt;

	drop_base_table_stmt := 'DROP TABLE ' || schema_name || '.' || old_table_name  || ';';
    EXECUTE drop_base_table_stmt;

END;
\$BODY\$;

ALTER FUNCTION public.create_partition_tables(text, text, text, integer)
    OWNER TO zchain_user;"""

# Executing script on the sharder postgres
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Executing script on postgres.
===============================================================================================================================================================================  \e[39m"
docker exec sharder-postgres-1 psql -U zchain_user -d events_db -c """BEGIN; SELECT create_partition_tables('public', 'transactions', 'round', 2000000); SELECT create_partition_tables('public', 'blocks', 'round', 2000000); COMMIT;"""

# Deploying new release tag on sharder
echo -e "\n\e[93m===============================================================================================================================================================================
                                                                            Deploying new release tag v1.13.6 on sharder.
===============================================================================================================================================================================  \e[39m"
export TAG=v1.13.6
yq e -i ".services.sharder.image = \"0chaindev/sharder:${TAG}\"" /var/0chain/sharder/ssd/docker.local/build.sharder/p0docker-compose.yaml
cd /var/0chain/sharder/ssd/docker.local/sharder1/
sudo bash ../bin/start.p0sharder.sh /var/0chain/sharder/ssd /var/0chain/sharder/hdd
