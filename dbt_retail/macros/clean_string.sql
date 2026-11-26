{% macro clean_string(column_name, case='none') %}

    {% if case == 'upper' %}
        UPPER(TRIM({{ column_name }}))

    {% elif case == 'lower' %}
        LOWER(TRIM({{ column_name }}))

    {% elif case == 'initcap' %}
        INITCAP(TRIM({{ column_name }}))

    {% else %}
        TRIM({{ column_name }})

    {% endif %}

{% endmacro %}
