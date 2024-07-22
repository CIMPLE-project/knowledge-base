#!/bin/sh

isql-v -U dba -P "${DBA_PASSWORD}" < /scripts/prefixes.sql
