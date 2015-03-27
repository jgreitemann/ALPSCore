#
# This cmake script adds test to a project from the 'test' directory in the ALPS module
#

# check xml output
option(TestXMLOutput "Output tests to xml" OFF)

# Find gtest or otherwise fetch it into the build_dir/gtest
function(UseGtest)  
    set (gtest_root ${ARGN})
    if (DEFINED gtest_root)
        message(STATUS "gtest source specified at ${gtest_root}")
        find_path(gtest_root NAMES "include/gtest/gtest.h" HINTS ${gtest_root})
        if (NOT IS_DIRECTORY ${gtest_root})
            message(WARNING "Provided wrong GTEST_ROOT. Please unset GTEST_ROOT - gtest will be fetched")
            unset(gtest_root CACHE)
        endif()
    endif()

    if (NOT DEFINED gtest_root)
        find_path(gtest_root1 NAMES "include/gtest/gtest.h" HINTS ${CMAKE_SOURCE_DIR}/gtest-1.6.0  ${CMAKE_SOURCE_DIR}/gtest-1.7.0  ${CMAKE_SOURCE_DIR}/gtest   ${CMAKE_BINARY_DIR}/gtest)
        if (IS_DIRECTORY ${gtest_root1})
            set (gtest_root ${gtest_root1})
        else()
            message(STATUS "Trying to fetch gtest via subversion")
            find_package(Subversion)
            execute_process(COMMAND "${Subversion_SVN_EXECUTABLE}" "checkout" "http://googletest.googlecode.com/svn/trunk/" "gtest" WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
            set (gtest_root "${CMAKE_BINARY_DIR}/gtest")
        endif()
        unset (gtest_root1 CACHE)
    endif()

    message(STATUS "gtest is in ${gtest_root}")
    if (NOT TARGET ${gtest_root})
        add_subdirectory(${gtest_root} ${PROJECT_BINARY_DIR}/gtest)
    endif()
            
    # export gtest variables
    set (GTEST_ROOT ${gtest_root} PARENT_SCOPE)
    set (GTEST_INCLUDE_DIR ${gtest_root}/include PARENT_SCOPE)
    set (GTEST_MAIN_LIBRARIES gtest_main PARENT_SCOPE)
    set (GTEST_MAIN_LIBRARY gtest_main PARENT_SCOPE)
    set (GTEST_LIBRARY gtest PARENT_SCOPE)
endfunction()

# enable testing with gtest - fetch it if needed
if (NOT tests_are_already_enabled) 
    find_package(GTest QUIET)

    if (NOT GTEST_FOUND) 
        UseGtest(${GTEST_ROOT})
        find_package(GTest)
    endif (NOT GTEST_FOUND) 

    # set (LINK_TEST  ${GTEST_MAIN_LIBRARIES}) 
    include_directories(${GTEST_INCLUDE_DIRS})
    set(tests_are_already_enabled TRUE)
endif(NOT tests_are_already_enabled)

# custom function to add test with xml output and linked to gtest
# arg0 - test (assume the source is ${test}.cpp)
# optional arg: NOMAIN: do not link libgtest_main containing main()
# optional arg: MAIN: do link libgtest_main containing main()
# optional arg: PARTEST: run test in parallel using N processes, where N is run-time value of environment variable ALPS_TEST_MPI_NPROC
#               (or 1 if the variable is not set) (FIXME: make this a configurable constant!)
# optional arg: directory containing the source file 
function(alps_add_gtest test)
    if (TestXMLOutput)
        set (test_xml_output --gtest_output=xml:${test}.xml)
    endif(TestXMLOutput)

    unset(source)
    set (nomain 0)
    set (partest 0)
    foreach(a ${ARGN})
        if (${a} STREQUAL "NOMAIN")
          set (nomain 1)
        elseif (${a} STREQUAL "MAIN")
          set (nomain 0)
        elseif (${a} STREQUAL "PARTEST")
          set (partest 1)
        else()
          if (DEFINED source)
            message(FATAL_ERROR "Incorrect use of alps_add_gtest(testname [MAIN|NOMAIN] [PARTEST] [test_src])")
          endif()
          set (source "${a}/${test}.cpp")
        endif()
    endforeach()
    if (NOT DEFINED source)
        set(source "${test}.cpp")
    endif()
    
    add_executable(${test} ${source})

    if (nomain)
        set(link_test ${GTEST_LIBRARY})
    else()
        set(link_test ${GTEST_MAIN_LIBRARIES})
    endif()

    target_link_libraries(${test} ${PROJECT_NAME} ${LINK_ALL} ${link_test})
    # FIXME: if compiler supports MPI directly, the MPIEXEC program is not deduced!
    # FIXME: in the MPI test command, POSIX shell is assumed
    if (partest AND MPIEXEC)
        set(cmd "/bin/sh" "-c" "${MPIEXEC} ${MPIEXEC_NUMPROC_FLAG} \${ALPS_TEST_MPI_NPROC:-1} ${MPIEXEC_PREFLAGS} ${test} ${MPIEXEC_POSTFLAGS}")
    else()
        set(cmd ${test})
    endif()
    add_test(NAME ${test} COMMAND ${cmd} ${test_xml_output})
endfunction(alps_add_gtest)
