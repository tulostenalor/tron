## tron
A lightweight engine for running instrumentation tests on multiple Android devices in parallel.

## Features
- Simple configuration
- Reactive test sharding execution
- Filter tests by package, class and/or annotation
- JUnit and HTML report generation
- Videos, instead of screenshots

## Configuration
 - Suplement a config file (located in <b>./config/config</b>) with application information:
    - Main and test app package name, test runner name
    - Update paths and prefixes for both main and test app (used for installation on devices):
        - Default location is: <b> ./app/</b>
        - Default prefix for main app: <b>*-debug.apk</b>
        - Default prefix for test app: <b>*-debug-androidTest.apkk</b>
    - Decide upon which artefacts to colled on success and/or failures:
        - Video
        - Logcat
        - Shared preferences
        - Database
        - Bugreport
    - Configure device state when tests are executed (brightness, animations enabled)
    - Enable or disable JUnit report genertion

## Running
Once basic configuration is complete tests can be executed by simply running: <b>./tron.sh</b>. This will shard all avaiable tests across all available devices, however <b>tron</b> can be supplied with an additional parameters:
- <b>-d</b> => selected devices
    -definition: comma separated list of devices (serial numbers to be precise) to run tests on
    -note: if no devices is passed all connected devices will be used
    -example: `-d abcd1234`
- <b>-p</b> => fitler by package name
    - definition: comma separated list of packages to be included into a test run
    - note: each item in the list should exclude base package name 
    - example: `-p integration` (for: com.test.example.instrumentation)
- <b>-c</b> => filter by class/test name
    - definition: comma separated list of classes/tests to be included into a test run
    - note: each item in the list should exclude base package name 
    - example: `-c integration.Class` (for: com.test.example.instrumentation.Class) or `-d integration.Class#Test1` (for: com.test.example.instrumentation.Class#Test1)
- <b>-a</b> => filter by annotation
    - definition: a name of annotation to filter tests by
    - note: this will be applied to both package and class filters (only test matching package/class & annotation will be run)
    - example: `-a SmallTest` (will only run tests with that annotation)
- <b>-m</b> => execition mode
    - definition: test execution mode (concurrent or sharding)
    - note: default mode (false) is sharding
    - example `-m true` (to run tests concurrently) | `-m false` (to shard the tests)

## Example
An example configuration alongside with test application has been provided in <b>./example</b> folder.







