project(getVertex)

cmake_minimum_required(VERSION 2.6)

find_package( OpenCV REQUIRED )

include_directories( ${CMAKE_SOURCE_DIR}/lib   )

add_executable(GetVertex GetVertex.cpp lib/openCV_util.cpp lib/vertex.cpp)

target_link_libraries(GetVertex ${OpenCV_LIBS} )