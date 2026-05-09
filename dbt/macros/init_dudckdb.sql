{% macro init_duckdb() %}
    PRAGMA memory_limit='10GB';
    PRAGMA temp_directory='/workspaces/tmp_duckdb';
{% endmacro %}