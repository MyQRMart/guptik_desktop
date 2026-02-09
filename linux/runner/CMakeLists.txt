cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# --- NUCLEAR FIX START ---
# 1. Force PkgConfig to find GTK and its include directories
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

# 2. Print the found paths to the terminal (for debugging)
message(STATUS "GTK Include Dirs: ${GTK_INCLUDE_DIRS}")
# --- NUCLEAR FIX END ---

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

apply_standard_settings(${BINARY_NAME})

# 3. Add the compiler flags (Definitions)
target_compile_options(${BINARY_NAME} PRIVATE ${GTK_CFLAGS_OTHER})
add_definitions(${GTK_CFLAGS_OTHER})
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# 4. CRITICAL: Explicitly add the include directories found in step 1
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}" ${GTK_INCLUDE_DIRS})

# 5. Link libraries
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE ${GTK_LIBRARIES})