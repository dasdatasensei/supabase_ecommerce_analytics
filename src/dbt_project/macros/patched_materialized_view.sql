/*
This file patches the conflict between the two materialized_view macros
in dbt Core by providing our own implementation.
*/

{% macro materialization_materialized_view_default(model, relation) %}
  {%- set existing_relation = load_relation(relation) -%}
  {%- set target_relation = this.incorporate(type='view') -%}

  -- Setup
  {{ run_hooks(pre_hooks, inside_transaction=False) }}
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  -- If there's an existing relation with this name, drop it
  {% if existing_relation is not none %}
      {{ adapter.drop_relation(existing_relation) }}
  {% endif %}

  -- Build the materialized view
  {% call statement('main') %}
    {{ create_view_as(target_relation, sql) }}
  {% endcall %}

  -- Cleanup
  {{ run_hooks(post_hooks, inside_transaction=True) }}
  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}
{% endmacro %}