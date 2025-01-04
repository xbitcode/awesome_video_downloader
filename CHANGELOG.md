## 0.1.4

* Added copyWith methods to all models for better immutability
* Added proper error handling for quality selection
* Added resolution and bitrate formatting utilities
* Added documentation for VideoQuality model
* Added type safety improvements
* Fixed formatting in example app
* Updated README with quality selection examples
* Improved code organization and documentation

## 0.1.3

* Added video quality selection support
* Added VideoQuality model for quality information
* Added getAvailableQualities method for HLS/DASH streams
* Added quality selection dialog UI component
* Added bitrate and resolution information
* Added HDR detection support
* Added comprehensive tests for quality selection
* Updated example app with quality selection UI
* Improved documentation for quality selection features

## 0.1.2

* Fixed stream handling in method channel tests
* Improved download progress stream reliability
* Added proper cleanup for event channels
* Fixed timeout issues in integration tests
* Added speed calculation tests
* Updated example app with better progress display
* Fixed stream completion handling
* Added proper error handling for platform channels
* Improved documentation for stream usage

## 0.1.1

* Added proper initialization check for Flutter bindings
* Improved error messages for initialization failures
* Added documentation for initialization requirements
* Fixed state tracking in download progress
* Improved type safety with DownloadState enum
* Added formatted progress and speed getters
* Reorganized models with BaseDownloadInfo
* Added proper error handling for download operations

## 0.1.0

* Initial release
* Support for downloading videos in multiple formats (HLS, DASH, MP4)
* Background download support
* Progress tracking
* Pause, resume, and cancel functionality
* Quality selection for adaptive streams
* Cross-platform support (iOS & Android)
