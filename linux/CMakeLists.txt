# Project-level configuration.
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "axichat")
# The unique GTK application identifier for this application. See:
# https://wiki.gnome.org/HowDoI/ChooseApplicationID
set(APPLICATION_ID "im.axi.axichat")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Load bundled libraries from the lib/ directory relative to the binary.
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Define build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
find_program(AXICHAT_PYTHON3_EXECUTABLE NAMES python3 python REQUIRED)
pkg_search_module(AXICHAT_WPE_WEBKIT QUIET
  wpe-webkit-2.0
  wpe-webkit-1.1
  wpe-webkit-1.0
)

set(AXICHAT_WPE_RUNTIME_SOURCE_DIR "")
set(AXICHAT_WPE_DATA_SOURCE_DIR "")
if(AXICHAT_WPE_WEBKIT_FOUND)
  pkg_get_variable(AXICHAT_WPE_WEBKIT_LIBDIR "${AXICHAT_WPE_WEBKIT_MODULE_NAME}" libdir)
  pkg_get_variable(AXICHAT_WPE_WEBKIT_PREFIX "${AXICHAT_WPE_WEBKIT_MODULE_NAME}" prefix)

  set(_axichat_wpe_runtime_candidates
    "${AXICHAT_WPE_WEBKIT_LIBDIR}/${AXICHAT_WPE_WEBKIT_MODULE_NAME}"
    "${AXICHAT_WPE_WEBKIT_LIBDIR}/wpe-webkit-2.0"
    "${AXICHAT_WPE_WEBKIT_LIBDIR}/wpe-webkit-1.1"
    "${AXICHAT_WPE_WEBKIT_LIBDIR}/wpe-webkit-1.0"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/libexec/${AXICHAT_WPE_WEBKIT_MODULE_NAME}"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/libexec/wpe-webkit-2.0"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/libexec/wpe-webkit-1.1"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/libexec/wpe-webkit-1.0"
  )
  list(REMOVE_DUPLICATES _axichat_wpe_runtime_candidates)
  foreach(candidate ${_axichat_wpe_runtime_candidates})
    if(EXISTS "${candidate}/WPEWebProcess")
      set(AXICHAT_WPE_RUNTIME_SOURCE_DIR "${candidate}")
      break()
    endif()
  endforeach()

  set(_axichat_wpe_data_candidates
    "${AXICHAT_WPE_WEBKIT_PREFIX}/share/${AXICHAT_WPE_WEBKIT_MODULE_NAME}"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/share/wpe-webkit-2.0"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/share/wpe-webkit-1.1"
    "${AXICHAT_WPE_WEBKIT_PREFIX}/share/wpe-webkit-1.0"
  )
  list(REMOVE_DUPLICATES _axichat_wpe_data_candidates)
  foreach(candidate ${_axichat_wpe_data_candidates})
    if(EXISTS "${candidate}/inspector.gresource")
      set(AXICHAT_WPE_DATA_SOURCE_DIR "${candidate}")
      break()
    endif()
  endforeach()

  if(NOT AXICHAT_WPE_RUNTIME_SOURCE_DIR)
    message(WARNING
      "Axichat could not find a WPE helper directory for ${AXICHAT_WPE_WEBKIT_MODULE_NAME}; "
      "the bundle may fail on machines without a matching host install.")
  endif()

  if(NOT AXICHAT_WPE_DATA_SOURCE_DIR)
    message(WARNING
      "Axichat could not find WPE shared data for ${AXICHAT_WPE_WEBKIT_MODULE_NAME}; "
      "WebKit inspector resources may be missing from the bundle.")
  endif()
endif()

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the unbundled copy, put it in a subdirectory instead of
# the default top-level location.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# Some generated Linux plugins inherit the absolute path to Flutter's ephemeral
# engine directory as their RUNPATH. Override that here so packaged artifacts
# only use the bundled lib/ directory at runtime.
foreach(plugin ${FLUTTER_PLUGIN_LIST})
  if(TARGET ${plugin}_plugin)
    set_target_properties(${plugin}_plugin PROPERTIES
      BUILD_WITH_INSTALL_RPATH TRUE
      BUILD_RPATH "$ORIGIN"
      INSTALL_RPATH "$ORIGIN")
  endif()
endforeach()

set(AXICHAT_PLUGIN_BUNDLE_LIBRARIES "")
foreach(plugin ${FLUTTER_PLUGIN_LIST})
  if(TARGET ${plugin}_plugin)
    list(APPEND AXICHAT_PLUGIN_BUNDLE_LIBRARIES "lib${plugin}_plugin.so")
  endif()
endforeach()


# === Installation ===
# By default, "installing" just makes a relocatable bundle in the build
# directory.
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Start with a clean build bundle directory every time.
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")
set(INSTALL_BUNDLE_SHARE_DIR "${CMAKE_INSTALL_PREFIX}/share")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

if(AXICHAT_WPE_RUNTIME_SOURCE_DIR)
  get_filename_component(AXICHAT_WPE_RUNTIME_DIR_NAME "${AXICHAT_WPE_RUNTIME_SOURCE_DIR}" NAME)
  install(DIRECTORY "${AXICHAT_WPE_RUNTIME_SOURCE_DIR}/"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}/${AXICHAT_WPE_RUNTIME_DIR_NAME}"
    USE_SOURCE_PERMISSIONS
    COMPONENT Runtime)
endif()

if(AXICHAT_WPE_DATA_SOURCE_DIR)
  get_filename_component(AXICHAT_WPE_DATA_DIR_NAME "${AXICHAT_WPE_DATA_SOURCE_DIR}" NAME)
  install(DIRECTORY "${AXICHAT_WPE_DATA_SOURCE_DIR}/"
    DESTINATION "${INSTALL_BUNDLE_SHARE_DIR}/${AXICHAT_WPE_DATA_DIR_NAME}"
    USE_SOURCE_PERMISSIONS
    COMPONENT Runtime)
endif()

# Mirror the WPE runtime symlink layout used by the plugin's example app so the
# bundle can resolve the bundled WebKit libraries on machines without matching
# system packages.
install(CODE "
  set(LIB_DIR \"${INSTALL_BUNDLE_LIB_DIR}\")

  macro(create_wpe_symlinks LIB_PATTERN SONAME_BASE)
    file(GLOB LIB_FILES \"\${LIB_DIR}/\${LIB_PATTERN}\")
    if(LIB_FILES)
      list(GET LIB_FILES 0 REAL_LIB)
      get_filename_component(REAL_LIB_NAME \"\${REAL_LIB}\" NAME)

      set(SONAME_LINK \"\${LIB_DIR}/\${SONAME_BASE}.so.1\")
      if(NOT EXISTS \"\${SONAME_LINK}\")
        execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
          \"\${REAL_LIB_NAME}\" \"\${SONAME_LINK}\")
      endif()

      set(SO_LINK \"\${LIB_DIR}/\${SONAME_BASE}.so\")
      if(NOT EXISTS \"\${SO_LINK}\")
        execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
          \"\${SONAME_BASE}.so.1\" \"\${SO_LINK}\")
      endif()
    endif()
  endmacro()

  create_wpe_symlinks(\"libWPEWebKit-2.0.so.*.*.*\" \"libWPEWebKit-2.0\")
  create_wpe_symlinks(\"libwpe-1.0.so.*.*.*\" \"libwpe-1.0\")
  create_wpe_symlinks(\"libWPEBackend-fdo-1.0.so.*.*.*\" \"libWPEBackend-fdo-1.0\")

  if(EXISTS \"\${LIB_DIR}/libWPEBackend-fdo-1.0.so.1\")
    set(DEFAULT_BACKEND_LINK \"\${LIB_DIR}/libWPEBackend-default.so\")
    if(NOT EXISTS \"\${DEFAULT_BACKEND_LINK}\")
      execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
        \"libWPEBackend-fdo-1.0.so.1\" \"\${DEFAULT_BACKEND_LINK}\")
    endif()
  endif()
  " COMPONENT Runtime)

install(CODE "
  set(PLUGIN_RPATH \"${FLUTTER_MANAGED_DIR}/ephemeral\")
  foreach(PLUGIN_LIB ${AXICHAT_PLUGIN_BUNDLE_LIBRARIES})
    set(PLUGIN_FILE \"${INSTALL_BUNDLE_LIB_DIR}/\${PLUGIN_LIB}\")
    if(EXISTS \"\${PLUGIN_FILE}\")
      file(RPATH_CHANGE
        FILE \"\${PLUGIN_FILE}\"
        OLD_RPATH \"\${PLUGIN_RPATH}\"
        NEW_RPATH \"\$ORIGIN\")
    endif()
  endforeach()
  " COMPONENT Runtime)

install(CODE "
  file(GLOB WPE_WEBKIT_LIBS \"${INSTALL_BUNDLE_LIB_DIR}/libWPEWebKit-*.so.*.*.*\")
  foreach(WPE_WEBKIT_LIB \${WPE_WEBKIT_LIBS})
    execute_process(
      COMMAND \"${AXICHAT_PYTHON3_EXECUTABLE}\"
              \"${CMAKE_CURRENT_SOURCE_DIR}/../tool/patch_linux_wpe_runtime_paths.py\"
              \"\${WPE_WEBKIT_LIB}\"
      RESULT_VARIABLE PATCH_RESULT)
    if(NOT PATCH_RESULT EQUAL 0)
      message(FATAL_ERROR \"Failed to patch bundled WPE runtime paths in \${WPE_WEBKIT_LIB}\")
    endif()
  endforeach()
  " COMPONENT Runtime)

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Install Linux application icon alongside the bundle and into the icon theme
# so desktops can pick it up automatically.
set(LINUX_APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/../assets/icons/generated/app_icon_linux.png")
if(EXISTS "${LINUX_APP_ICON}")
  install(FILES "${LINUX_APP_ICON}"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    RENAME "app_icon.png"
    COMPONENT Runtime)

  install(FILES "${LINUX_APP_ICON}"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor/256x256/apps"
    RENAME "im.axi.axichat.png"
    COMPONENT Runtime)
endif()

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/im.axi.axichat.desktop"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/share/applications"
  COMPONENT Runtime)
