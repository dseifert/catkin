# set directory for test results
if(ENV{CATKIN_TEST_RESULTS_DIR})
  message("Override test results directory with environment variable CATKIN_TEST_RESULTS_DIR=${CATKIN_TEST_RESULTS_DIR}")
  set(CATKIN_TEST_RESULTS_DIR $ENV{CATKIN_TEST_RESULTS_DIR} CACHE INTERNAL "")
else()
  set(CATKIN_TEST_RESULTS_DIR ${CMAKE_BINARY_DIR}/test_results CACHE INTERNAL "")
endif()

# create target to build tests
if(NOT TARGET tests)
  add_custom_target(tests)
  message("TODO: implement add_roslaunch_check() in rostest-extras.cmake")
endif()

# create target to run all tests
# it uses the dot-prefixed test targets to depend on building all tests and cleaning test results before the tests are executed
if(NOT TARGET run_tests)
  add_custom_target(run_tests)
endif()

# create target to clean test results
if(NOT TARGET clean_test_results)
  add_custom_target(clean_test_results
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CATKIN_TEST_RESULTS_DIR})
endif()

#
# Create a test target, integrate it with the run_tests infrastructure
# and post-process the junit result.
#
# All test results go under ${CATKIN_TEST_RESULTS_DIR}/${PROJECT_NAME}/..
#
# This function is only used internally by the various
# catkin_add_*test() functions.
#
function(catkin_run_tests_target type name xunit_filename)
  parse_arguments(_testing "COMMAND;WORKING_DIRECTORY" "" ${ARGN})
  if(_testing_DEFAULT_ARGS)
    message(FATAL_ERROR "catkin_run_tests_target() called with unused arguments: ${_testing_DEFAULT_ARGS}")
  endif()

  # create meta target to trigger all tests of a project
  if(NOT TARGET run_tests_${PROJECT_NAME})
    add_custom_target(run_tests_${PROJECT_NAME})
    # create hidden meta target which depends on hidden test targets which depend on clean_test_results
    add_custom_target(.run_tests_${PROJECT_NAME})
    # run_tests depends on this hidden target hierarchy to clear test results before running all tests
    add_dependencies(run_tests .run_tests_${PROJECT_NAME})
  endif()
  # create meta target to trigger all tests of a specific type of a project
  if(NOT TARGET run_tests_${PROJECT_NAME}_${type})
    add_custom_target(run_tests_${PROJECT_NAME}_${type})
    add_dependencies(run_tests_${PROJECT_NAME} run_tests_${PROJECT_NAME}_${type})
    # hidden meta target which depends on hidden test targets which depend on clean_test_results
    add_custom_target(.run_tests_${PROJECT_NAME}_${type})
    add_dependencies(.run_tests_${PROJECT_NAME} .run_tests_${PROJECT_NAME}_${type})
  endif()
  # create target for test execution
  set(results ${CATKIN_TEST_RESULTS_DIR}/${PROJECT_NAME}/${xunit_filename})
  if (_testing_WORKING_DIRECTORY)
    set(working_dir_arg "--working-dir" ${_testing_WORKING_DIRECTORY})
  endif()
  assert(CATKIN_ENV)
  set(cmd ${CATKIN_ENV} ${PYTHON_EXECUTABLE}
    ${catkin_EXTRAS_DIR}/test/run_tests.py --results ${results} ${working_dir_arg} ${_testing_COMMAND})
  add_custom_target(run_tests_${PROJECT_NAME}_${type}_${name}
    COMMAND ${cmd})
  add_dependencies(run_tests_${PROJECT_NAME}_${type} run_tests_${PROJECT_NAME}_${type}_${name})
  # hidden test target which depends on building all tests and cleaning test results
  add_custom_target(.run_tests_${PROJECT_NAME}_${type}_${name}
    COMMAND ${cmd})
  add_dependencies(.run_tests_${PROJECT_NAME}_${type} .run_tests_${PROJECT_NAME}_${type}_${name})
  add_dependencies(.run_tests_${PROJECT_NAME}_${type}_${name} clean_test_results)
  add_dependencies(.run_tests_${PROJECT_NAME}_${type}_${name} tests)
endfunction()
