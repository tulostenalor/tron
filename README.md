## tron
A lightweight engine for running instrumentation tests on multiple Android devices in parallel.

## Features
- All-in-one configuration
- Reactive test sharding execution
- Package, class, test and/or annotation filters
- Configurable test conditions
- JUnit and HTML report generation
- Videos, instead of screenshots

## Configuration
 - Suplement a config file (located in <b>config/config</b>) with test application information:
    - Main and test app package names, test runner name
    - Update paths and prefixes for both main and test app (used for installation on devices):
        - Default location is: <b> app/</b>
        - Default prefix for main app: <b>*-debug.apk</b>
        - Default prefix for test app: <b>*-debug-androidTest.apkk</b>
    - Decide upon artefacts to be collected on success and/or failures:
        - Video
        - Logcat
        - Shared preferences
        - Database
        - Bugreport
    - Configure device state when tests are executed (brightness, animation enabled)
    - Enable or disable JUnit/HTML report genertion

## Running
Once basic configuration is complete tests can be executed by simply running: <b>tron.sh</b>. This will shard all avaiable tests across all available devices, however <b>tron</b> can be supplied with an additional parameters:
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

## Test conditions
It is possible to enforce a requirement for running specific test, class or package on a desired device SDK version. This is useful when testing for example permissions or other OS based features. Configuration is done by creating `config/conditions` (default path) file and adding specifications (each in new line) in a following format:

- `CONDITION_SELECTOR|CONDITION_SDK|CONDITION_OPERATOR`

- CONDITION_SELECTOR => a test string filter
    - definition: a string compared with running tests, if match is found condition check for device will occur
    - note: selector can be a specific test (com.test.example.instrumentation.Class#Test1), class (com.test.example.instrumentation.Class) or package (com.test.example.instrumentation)
- CONDITION_SDK => a SDK version integer
    - definition: used as one of the arguments to determine if device is meeting criteria for running the test
- CONDITION_OPERATOR => comparison operator
    - definition: an operator used for comparing the arguments (CONDITION_SDK & DEVICE_SDK)
    - note: standard operators can be used, e.g `-gt`, `lt`, `eq`, etc.

For example, following condition: `com.test.example.instrumentation.Class|23|-gt` - will enforce that all tests under `Class` be run only on devices with SDK versoin `greater than 23`.

## Example
An example configuration alongside with test application has been provided in <b>example</b> folder.







