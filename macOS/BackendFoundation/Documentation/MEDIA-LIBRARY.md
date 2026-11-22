# ChargeMotion Media Library

## Scope

This component provides the backend storage/catalog layer for imported wallpaper videos.
It is deliberately independent of SwiftUI so a later frontend can call it.

## Supported formats

- MP4
- MOV
- M4V

Other formats are rejected with a localized error. Transcoding and thumbnail generation
are intentionally separate future components.

## Storage

Imported files are copied into:

`~/Library/Application Support/ChargeMotion/Media/`

The catalog is stored in `media-library.json` in the parent application-support directory.
The source file can be moved or deleted after a successful import.

When importing from a user-selected URL, the store attempts security-scoped access and
releases it after the copy. It does not retain external file bookmarks because it copies
media into app-managed storage.

## Public API

- `MediaLibraryStore.listAssets()`
- `MediaLibraryStore.importFile(from:displayName:)`
- `MediaLibraryStore.fileURL(for:)`
- `MediaLibraryStore.renameAsset(_:to:)`
- `MediaLibraryStore.removeAsset(_:)`

`MediaLibraryStore` is an actor; call its methods with `await` from asynchronous code.

## Validation

The included XCTest suite covers empty catalogs, unsupported extensions, import and
catalog persistence, rename, and removal. The package has not been compiled in this
Windows environment. Run `swift test` on a Mac with Xcode command-line tools installed.
