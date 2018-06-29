#!/usr/bin/env bash

function _source_utils() {
	if [[ -d "bash-utils" && ! "$(ls -A bash-utils)" ]] ; then
		git submodule init && git submodule update
	fi
	source "bash-utils/utils.sh"
	return $?
}

function _usage_main() {
	_menu_lign
	_menu_header
	_menu_lign "[ OPTIONS ]"
	_menu_option "-h|--help" "Print this helper."
	_menu_option "-n|--name" "The tool name."
	_menu_option "-c|--pkgname" "The catalog package name."
	_menu_option "-d|--description" "A string to describe the package."
	_menu_option "-v|--version" "The tool version."
	_menu_option "--root" "The root path of the binaries to package. Default is current local directory."
	_menu_option "--dependencies" "A string containing the list of dependencies."
	_menu_option "--profile" "Specifies the deployment profile to use. Default is official." "{official|dev}"
	_menu_option "--pkg-prefix" "The company prefix to use in the catalog. Default is ORG."
	_menu_option "--pkg-output" "The directory where to output the created package. Default is /tmp."
	_menu_option "--catalog-root" "The root path of the catalog where to upload the datastream. Default is /opt/opencsw/org."
	_menu_option "--verbose" "Print useful variables for debugging purpose."
	_menu_option "--reload-utils" "Reload the bash utils from the repo."
	_menu_lign
	_menu_footer
	_menu_lign
	return 0
}

function _set_default_args() {
	_pkg_prefix="${1}"
	_profile="${2}"
	_binaries_root="${3}"
	_pkg_output="${4}"
	_catalog_root="${5}"
}

function _get_org_package_deployment_path() {
	local profile toolname version
	if [[ ${#} -ne 3 ]] ; then _perror "Missing parameters to infer package standard deployment path!"; exit 1;
	else profile="${1}" ; toolname="${2}" ; version="${3}" ; fi
	case "${profile}" in
		official )
			_deployment_path="/opt/org/${toolname}/${version}" ;;
		dev )
			_deployment_path="/opt/org/developers" ;;
		*)
			_perror "Called with unknown profile: ${profile}" ; exit 1
	esac
	return 0
}

function _create_pkginfo() {
	local name pkg_name description version profile pkg_prefix
	_pdebug "_create_pkginfo: ${*}"
	if [[ ${#} -ne 6 ]] ; then _perror "Missing parameters to create pkginfo"; exit 1;
	elif [[ ${1} == "" || ${2} == "" || ${3} == "" || ${4} == "" || ${5} == "" || ${6} == "" ]] ; then _perror "Parameters are missing, cannot createpkginfo"; exit 1;
	else  name="${1}" ; pkg_name="${2}" ; description="${3}" ; version="${4}" ; profile="${5}"; pkg_prefix="${6}" ; fi
	_get_org_package_deployment_path "${profile}" "${name}" "${version}"
	_pkg_prefix=${pkg_prefix}
	_pdebug "name: ${name}"
	_pdebug "pkgname: ${pkg_name}"
	_pdebug "description: ${description}"
	_pdebug "version: ${version}"
	_pdebug "profile: ${profile}"
	_pdebug "prefix: ${pkg_prefix}"
	_pdebug "binaries root: ${_binaries_root}"
	_pdebug "deployment_path: ${_deployment_path}"
	cat <<EOF > "${_binaries_root}/pkginfo"
PKG=${pkg_prefix}${pkg_name}
NAME=${pkg_name} - ${description}
ARCH=$(uname -p)
VERSION=${version},REV=$(date +%Y.%m.%d)
CATEGORY=application
BASEDIR=${_deployment_path}
VENDOR=org
EMAIL=coretechinfra@org.com
CLASSES=none cswalternatives cswtexinfo
OPENCSW_OS_ARCH=$(uname -p)
OPENCSW_OS_VERSION=$(uname -s)$(uname -r)
OPENCSW_CATALOGNAME=${pkg_name}
EOF
  _pinfo "Created pkginfo: ${pkg_name} (${pkg_prefix}${pkg_name}) [${version},REV=$(date +%Y.%m.%d)][$(uname -s).$(uname -r)-$(uname -p)]"
  return 0
}

function _create_depend() {
	local dependencies dependency dependency_arr catalog_entry_count dep_catalog_name dep_name dep_description dep_version
	rm "${_binaries_root}/depend" 2>/dev/null
	dependencies=(${1})
	if [[ ${#dependencies[@]} -ne 0 && ${_dependencies[@]} != "" ]] ; then
		_pinfo "Looking up ${#dependencies[@]} dependencies..."
		for dependency in "${dependencies[@]}" ; do
			unset dep_version
			IFS='@' read -ra dependency_arr <<< "${dependency}"
			dep_catalog_name=${dependency_arr[0]}
			dep_version=${dependency_arr[1]}
			_pdebug "dep_catalog_name: ${dep_catalog_name}"
			_pdebug "dep_version: ${dep_version}"
			_pdebug "pkgutil --parse -a ${dep_catalog_name}"
			catalog_entry_count=$(pkgutil --parse -a "${dep_catalog_name}" | wc -l | xargs)
			_pdebug "catalog_entry_count: ${catalog_entry_count}"
			if [[ ${catalog_entry_count} -eq  0 ]]; then
				_perror "Could not find the dependency ${dep_catalog_name} in the catalog!"
			elif [[ "${dep_version}" == "" && ${catalog_entry_count} -gt  1 ]]; then
				_pdebug "multiple catalog entries and no version specified"
				_pdebug "pkgutil --parse -a ${dep_catalog_name}"
				dep_name="$(pkgutil --parse -a "${dep_catalog_name}" | awk '{print $1}' | tail -1)"
				_pdebug "pkgutil --parse -a ${dep_name} | awk '{print $3}' | tail -1"
				dep_version="$(pkgutil --parse -a "${dep_name}" | awk '{print $3}' | tail -1)"
				_pwarning "Found multiple available versions for the dependency ${dep_catalog_name}, the latest one will be taken by default: ${dep_version}"
			else
				_pdebug "single entry found in the catalog, or specific version specified on the command line"
				_pdebug "pkgutil --parse -a ${dep_catalog_name}"
				dep_name="$(pkgutil --parse -a "${dep_catalog_name}" | awk '{print $1}')"
			fi
			_pdebug "dep_name: ${dep_name}"
			_pdebug "pkgutil --parse --describe ^${dep_name}"
			dep_description="$(pkgutil --parse --describe ^"${dep_name}" | awk '{$1="" ; print $0}' 2>/dev/null | xargs)"
			_pdebug "dep_description: ${dep_description}"
			echo "P ${dep_catalog_name} ${dep_name} - ${dep_description}" >> "${_binaries_root}/depend"
		done
	else
		_pinfo "No dependencies declared for this package"
	fi
	return 0
}

function _create_prototype() {
	rm "${_binaries_root}/prototype" 2>/dev/null
	cd "${_binaries_root}" || { echo "Failed to change to binaries root directory: ${_binaries_root}"; exit 1; }
	pkgproto ./ > "${_binaries_root}/prototype" || { echo "Failed to generate protoype!"; exit 1; }
	cd "${OLDPWD}" || { echo "Failed to change back to previous directory: ${OLDPWD}"; exit 1; }
	sed "s/f none .*pkginfo.*/i pkginfo/g" "${_binaries_root}/prototype" > "${_binaries_root}/prototype.tmp" && mv "${_binaries_root}/prototype.tmp" "${_binaries_root}/prototype"
	sed "s/f none .*prototype.*/i prototype/g" "${_binaries_root}/prototype" > "${_binaries_root}/prototype.tmp" && mv "${_binaries_root}/prototype.tmp" "${_binaries_root}/prototype"
	if [[ -e "${_binaries_root}/depend" ]] ; then
		sed "s/f none .*depend.*/i depend/g" "${_binaries_root}/prototype" > "${_binaries_root}/prototype.tmp" && mv "${_binaries_root}/prototype.tmp" "${_binaries_root}/prototype"
	fi

	return 0
}

function _create_package() {
	local pkg_name
	if [[ ${1} == "" ]] ; then _perror "Cannot create a package without its name."; exit 1; fi
	pkg_name="${1}" ;
	_pdebug "package name: ${pkg_name}"
	_pdebug "binaries location: ${_binaries_root}"
	_pdebug "package location: ${_pkg_output}"
	cd "${_binaries_root}" || { echo "Failed to change to binaries root directory: ${_binaries_root}"; exit 1; }
	pkgmk -b $(pwd) -d "${_pkg_output}" -o >/dev/null 2>&1
	if [[ $? -ne 0 ]] ; then _perror "Failed to create package! (pkgmk -b ${_binaries_root} -d ${_pkg_output} -o)" ; exit 1; fi
	cd "${OLDPWD}" || { echo "Failed to change back to previous directory: ${OLDPWD}"; exit 1; }
	pkgchk -d "${_pkg_output}" "${_pkg_prefix}${pkg_name}" >/dev/null 2>&1
	if [[ $? -ne 0 ]] ; then _perror "Failed to check package ${_pkg_prefix}${pkg_name}! (pkgchk -d ${_pkg_output} ${_pkg_prefix}${pkg_name})" ; exit 1; fi
	_pinfo "Package ${_pkg_prefix}${pkg_name} created successfully"
	return 0
}

function _create_datastream() {
	local pkg_name datastream_name
	if [[ ${1} == "" ]] ; then _perror "Cannot create a datastream without the package name."; exit 1; fi
	pkg_name="${1}"
	_pdebug "package name: ${pkg_name}"
	_pdebug "package location: ${_pkg_output}"
	source "${_pkg_output}/${_pkg_prefix}${pkg_name}/pkginfo" 2>/dev/null
	datastream_name="${OPENCSW_CATALOGNAME}-${VERSION}-${OPENCSW_OS_VERSION}-${OPENCSW_OS_ARCH}-${PKG%${OPENCSW_CATALOGNAME}}"
	_pdebug "datastream: ${_pkg_output}/${datastream_name}.pkg"
	pkgtrans -o -s "${_pkg_output}" "${_pkg_output}/${datastream_name}.pkg" "${PKG}" 2>/dev/null
	if [[ $? -ne 0 ]] ; then _perror "Failed to create the datastream!" ; exit 1; fi
	gzip -f "${_pkg_output}/${datastream_name}.pkg"
	if [[ $? -ne 0 ]] ; then _perror "Failed to compress the datastream!" ; exit 1; fi
	_datastream="${_pkg_output}/${datastream_name}.pkg.gz"
	_pinfo "Package ${PKG} converted to datastream: ${datastream_name}.pkg"
	return 0
}

function _upload_to_repo() {
	local datastream catalog_path
	if [[ ${1} == "" ]] ; then _perror "Cannot upload to repo if datastream not specified."; exit 1; fi
	datastream="${1}"
	catalog_path="${_catalog_root}/$(uname -p)/$(uname -r)"
	_pdebug "datastream: ${datastream}"
	_pdebug "catalog_root: ${_catalog_root}"
	_pdebug "catalog_path: ${catalog_path}"
	_pinfo "Uploading datastream to remote repository ${catalog_path}..."
	cp "${datastream}" "${catalog_path}"
	if [[ $? -ne 0 ]] ; then _perror "Failed to upload the datastream to the repo!" ; exit 1; fi
	_pinfo "Re-indexing remote repository ${catalog_path}..."
	command -V bldcat >/dev/null 2>&1
	if [[ $? -ne 0 ]]; then
		_pwarning "The bldcat command was not found in the path, trying to install the CSWpkgutilplus package"
		pkgutil -y -i CSWpkgutilplus >/dev/null 2>&1 || { _perror "Failed to download the CSWpkgutilplus package, bldcat utility not available."; exit 1; }
	fi
	bldcat "${catalog_path}"
	if [[ $? -ne 0 ]] ; then _perror "Failed to re-index the repo!" ; exit 1; fi
	return 0
}

function _main() {
	local datastream
	_source_utils
	_parse_args "${@}"
	_set_default_args "${_pkg_prefix:-ORG}" "${_profile:-official}" "${_binaries_root:-$(pwd)}" "${_pkg_output:-/tmp}" "${_catalog_root:-/opt/opencsw/org}"
	_create_pkginfo "${_name}" "${_pkg_name}" "${_description}" "${_version}" "${_profile}" "${_pkg_prefix}"
	_create_depend "${_dependencies}"
	_create_prototype
	_create_package "${_pkg_name}"
	_create_datastream "${_pkg_name}"
	_upload_to_repo "${_datastream}"
	_psuccess "Package ${_name} was successfully created and uploaded."
	return 0
}

function _parse_args() {
	local values
	for arg in "${@}" ; do
		case "${arg}" in
			-h|--help)
				_usage_main
				exit 0
				;;
			--verbose)
				_verbose=true
				shift 1
				;;
			-n|--name)
				_name="${2}"
				shift 2
				;;
			-p|--pkgname)
				_pkg_name="${2}"
				shift 2
				;;
			-d|--description)
				_description="${2}"
				shift 2
				;;
			-v|--version)
				_version="${2}"
				shift 2
				;;
			--root)
				_binaries_root="${2}"
				shift 2
				;;
			--dependencies)
				_dependencies="${2}"
				shift 2
				;;
			--profile)
				values=(official dev)
				if _isinarray "${2}" "${values[@]}" ; then
					_profile="${2}"
					shift 2
				else
					_perror "The ${1} parameter can only take the following values: [${values[*]}]"
					exit 1
				fi
				;;
			--pkg-prefix)
				_pkg_prefix="${2}"
				shift 2
				;;
			--pkg-output)
				_pkg_output="${2}"
				shift 2
				;;
			--catalog-root)
				_catalog_root="${2}"
				shift 2
				;;
			--reload-utils)
				git submodule update --recursive --remote
				_source_utils
				shift 1
				;;
			*) _parsed_args=("${_parsed_args[@]} ${arg}")
		esac
	done
	return 0
}

_main "${@}"
