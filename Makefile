SHELL := /bin/bash
PROJECT := ios/GraceAtHand.xcodeproj
SCHEME := GraceAtHand
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: setup doctor generate build test test-core test-ios test-ui test-network validate preview release-check
setup:
	$(MAKE) doctor
	pnpm install --frozen-lockfile
	$(MAKE) generate
doctor:
	node tools/check-toolchain.mjs
generate:
	node tools/generate-tokens.mjs
	node tools/bundle-assets.mjs
	node tools/content.mjs bundle
	node tools/readings.mjs bundle
	xcodegen generate --spec ios/project.yml
build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
test: validate test-core
	node --test tools/tests/*.test.mjs
test-core:
	swift test --package-path ios/Packages/GraceCore --scratch-path build/GraceCore
test-ios: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath build/DerivedData -only-testing:GraceAtHandTests CODE_SIGNING_ALLOWED=NO test
test-ui: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath build/DerivedData -only-testing:GraceAtHandUITests CODE_SIGNING_ALLOWED=NO test
test-network: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Preview -destination '$(DESTINATION)' -derivedDataPath build/DerivedData -only-testing:GraceAtHandTests/PersistenceTests/testPreviewCatalogAndHTTPDownload CODE_SIGNING_ALLOWED=NO test
validate:
	node tools/content.mjs validate
	node tools/readings.mjs validate
preview:
	node tools/content.mjs preview
release-check:
	node tools/release-check.mjs
