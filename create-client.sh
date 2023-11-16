#!/bin/bash

args_count=$#

usage="
Add a client with protected resources.
$(basename "$0") [-h] [-e] [-u] [-p] [-t | --token t] --id id [--name name] [--default] [--authenticated] [--resource name] [--uris u1,u2] [--scopes s1,s2] [--users u1,u2] [--roles r1,r2]

where:
    -h                    show help message
    -e                    enviroment - local, develop, demo, production - defaults to local
    -u                    username used for authentication
    -p                    password used for authentication
    -t or --token         access token used for authentication
    --id                  client id
    --name                client name
    --default             add default resource - /* authenticated
    --authenticated       allow access to the resource when authenticated
    --resource            resource name
    --uris                resource uris - separated by comma (,)
    --scopes              resource scopes - separated by comma (,)
    --users               user names with access to the resource - separated by comma (,)
    --roles               role names with access to the resource - separated by comma (,)
"

TEMP=$(getopt -o he:u:p:t: --long id:,name:,description:,default,authenticated,resource:,uris:,scopes:,users:,roles: \
  -n "$(basename "$0")" -- "$@")

if [ $? != 0 ]; then
  exit 1
fi

eval set -- "$TEMP"

environment="local"
client_id=
client_name=
client_description=
resource_name=
resource_uris=
resource_scopes=
users=
roles=
authenticated=false

resources=()

add_resource() {
  if [ -z "${resource_scopes}" ]; then
    resource_scopes="access"
  fi
  IFS=',' read -ra resource_uris_array <<<"$resource_uris"
  IFS=',' read -ra resource_scopes_array <<<"$resource_scopes"
  IFS=',' read -ra users_array <<<"$users"
  IFS=',' read -ra roles_array <<<"$roles"
  if ((${#users_array[@]} == 0 && ${#roles_array[@]} == 0)); then
    resource="{
      \"name\": \"${resource_name}\",
      \"uris\": $(json_array "${resource_uris_array[@]}"),
      \"scopes\": $(json_array "${resource_scopes_array[@]}"),
      \"permissions\": {
        \"authenticated\": ${authenticated}
      }
    }"
  else
    resource="{
      \"name\": \"${resource_name}\",
      \"uris\": $(json_array "${resource_uris_array[@]}"),
      \"scopes\": $(json_array "${resource_scopes_array[@]}"),
      \"permissions\": {
        \"user\": $(json_array "${users_array[@]}"),
        \"role\": $(json_array "${roles_array[@]}")
      }
    }"
  fi
  resources+=("$resource")
  resource_name=
  resource_uris=
  resource_scopes=
  users=
  roles=
  authenticated=false
}

json_array() {
  echo -n '['
  while [ $# -gt 0 ]; do
    x=${1//\\/\\\\}
    echo -n "\"${x//\"/\\\"}\""
    [ $# -gt 1 ] && echo -n ', '
    shift
  done
  echo ']'
}

join_array() {
  local IFS="$1"
  shift
  echo "$*"
}

while true; do
  case "$1" in
  --id)
    client_id="$2"
    shift 2
    ;;
  --name)
    client_name="$2"
    shift 2
    ;;
  --description)
    client_description="$2"
    shift 2
    ;;
  --resource)
    if [ -n "${resource_name}" ]; then
      add_resource
    fi
    resource_name="$2"
    shift 2
    ;;
  --default)
    resource_name="Default Resource"
    resource_uris="/*"
    resource_scopes="access"
    users=
    roles=
    authenticated=true
    shift
    ;;
  --authenticated)
    authenticated="$1"
    shift
    ;;
  --uris)
    resource_uris="$2"
    shift 2
    ;;
  --scopes)
    resource_scopes="$2"
    shift 2
    ;;
  --users)
    users="$2"
    shift 2
    ;;
  --roles)
    roles="$2"
    shift 2
    ;;
  -e)
    environment="$2"
    shift 2
    ;;
  -u)
    username="$2"
    shift 2
    ;;
  -p)
    password="$2"
    shift 2
    ;;
  -t | --token)
    access_token="$2"
    shift 2
    ;;
  -h)
    echo "$usage"
    exit 1
    ;;
  --)
    shift
    break
    ;;
  *) break ;;
  esac
done

if [ "$args_count" -ne 0 ]; then
  if [ -n "${client_id}" ]; then
    add_resource
  fi
else
  read -rp "> Environment (local/develop/demo/production): " environment
  if [ -z "$environment" ]; then
    echo "Using default environment (local)"
    environment="local"
  fi
  # no args passed, ask for input
  if [ "$environment" != "local" ]; then
    read -rp "> Username (optional): " username
      read -rsp "> Password (optional): " password
      if [ -n "$password" ]; then
        echo "*********"
      else
        echo ""
      fi
      if [ -z "$username" ] && [ -z "$password" ]; then
        read -rsp "> Access token: " access_token
        if [ -n "$access_token" ]; then
          echo "******************"
        else
          echo ""
        fi
      fi
      if [ -z "$username" ] && [ -z "$password" ] && [ -z "$access_token" ]; then
        echo "Authentication is required"
        exit 1
      fi
  fi
  read -rp "> Client Id: " client_id
  read -rp "> Client Name (optional): " client_name
  read -rp "> Client Description (optional): " client_description
  read -rp "> Add resource? [y/N] " add_resource_answer
  resources=()
  while [ "$add_resource_answer" == y ]; do
    read -rp "> Resource name: " resource_name
    read -rp "> Resource URIs: " resource_uris
    read -rp "> Resource scopes (optional): " resource_scopes
    if [ -z "${resource_scopes}" ]; then
      echo "Using default scope (access)"
      resource_scopes="access"
    fi
    read -rp "> Users (optional): " users
    read -rp "> Roles (optional): " roles
    if [ -z "$users" ] && [ -z "$roles" ]; then
      read -rp "> Authenticated only? [y/N] " authenticated
      if [ "$authenticated" == y ]; then
        authenticated=true
      fi
    fi
    add_resource
    read -rp "> Add resource? [y/N] " add_resource_answer
  done
fi

if [ "$environment" != "local" ]; then
  if [ -z "$username" ] && [ -z "$password" ] && [ -z "$access_token" ]; then
    echo "> Authentication is required"
    exit 1
  fi
fi

if [ -z "$client_id" ]; then
  echo "Missing client id"
  exit 1
fi

url=
if [ "$environment" == "local" ]; then
  url="http://localhost:8080"
elif [[ "$environment" == "develop" || "$environment" == "demo" ]]; then
  url="https://identity.api.${environment}.eoepca.org"
elif [ "$environment" == "production" ]; then
  url="https://identity.api.eoepca.org"
else
  echo "Invalid environment $environment"
  exit 1
fi
endpoint="$url/clients"
payload=""
if ((${#resources[@]} == 0)); then
  payload="{
        \"clientId\": \"${client_id}\",
        \"name\": \"${client_name}\",
        \"description\": \"${client_description}\"
      }"
else
  payload="{
    \"clientId\": \"${client_id}\",
    \"name\": \"${client_name}\",
    \"description\": \"${client_description}\",
    \"resources\": [$(join_array , "${resources[@]}")]
  }"
fi
echo ""
echo "Adding client"
echo "$endpoint"
echo "$payload"
echo ""
if [[ -n "$username" && -n "$password" ]]; then
  curl -i \
    --user "$username:$password" \
    -H "Content-Type: application/json" \
    -X POST --data "$payload" "$endpoint"
elif [ -n "$access_token" ]; then
  curl -i \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $access_token" \
    -X POST --data "$payload" "$endpoint"
else
  curl -i \
    -H "Content-Type: application/json" \
    -X POST --data "$payload" "$endpoint"
fi