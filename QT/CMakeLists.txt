cmake_minimum_required(VERSION 3.24)
project(CH4ImagingHost VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(CTest)

find_package(Qt6 6.11 REQUIRED COMPONENTS Core Gui Widgets Test)

add_library(ch4_protocol STATIC
    src/protocol/frame_codec.cpp
    src/protocol/frame_codec.h
    src/protocol/generated_protocol.h
    src/protocol/generated_registers.h
)
target_include_directories(ch4_protocol PUBLIC src)
target_link_libraries(ch4_protocol PUBLIC Qt6::Core)

qt_add_executable(CH4ImagingHost WIN32
    src/app/main.cpp
    src/app/main_window.cpp
    src/app/main_window.h
)
target_link_libraries(CH4ImagingHost PRIVATE ch4_protocol Qt6::Gui Qt6::Widgets)
set_target_properties(CH4ImagingHost PROPERTIES OUTPUT_NAME "CH4-Imaging-Control")

if(WIN32)
    target_compile_definitions(CH4ImagingHost PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
endif()
if(MSVC)
    target_compile_options(ch4_protocol PRIVATE /W4 /utf-8)
    target_compile_options(CH4ImagingHost PRIVATE /W4 /utf-8)
else()
    target_compile_options(ch4_protocol PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(CH4ImagingHost PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(BUILD_TESTING)
    add_executable(protocol_tests
        tests/protocol_tests.cpp
    )
    target_link_libraries(protocol_tests PRIVATE ch4_protocol Qt6::Test)
    target_compile_definitions(protocol_tests PRIVATE
        CH4_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/.."
    )
    add_test(NAME protocol_tests COMMAND protocol_tests)
    set_property(TEST protocol_tests PROPERTY ENVIRONMENT_MODIFICATION
        "PATH=path_list_prepend:C:/Qt/6.11.2/mingw_64/bin"
        "PATH=path_list_prepend:C:/Qt/Tools/mingw1310_64/bin"
    )
endif()
