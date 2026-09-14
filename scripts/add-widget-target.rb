#!/usr/bin/env ruby
# Adds the FrijWidget WidgetKit extension target to Fridj.xcodeproj.
#
# Written as a script rather than done by hand because .pbxproj edits are easy
# to get subtly wrong and impossible to review. Idempotent: re-running is a
# no-op if the target already exists.
#
#   ruby scripts/add-widget-target.rb
require "xcodeproj"

PROJECT   = "Fridj.xcodeproj"
TARGET    = "FrijWidget"
APP       = "Fridj"
BUNDLE_ID = "com.hellofrij.frij.FrijWidget"
TEAM      = "5SAX25WKUQ"
IOS_MIN   = "26.0"

project = Xcodeproj::Project.open(PROJECT)

if project.targets.any? { |t| t.name == TARGET }
  puts "#{TARGET} already exists — nothing to do."
  exit 0
end

app_target = project.targets.find { |t| t.name == APP } or abort "no #{APP} target"

widget = project.new_target(:app_extension, TARGET, :ios, IOS_MIN)

# This project uses Xcode 16 file-system synchronized groups, so sources are
# picked up from the folder instead of being listed one by one. Match that
# rather than introducing a second, inconsistent style.
sync = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
sync.path = TARGET
sync.source_tree = "<group>"
project.main_group << sync
widget.file_system_synchronized_groups << sync

widget.build_configurations.each do |config|
  s = config.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"]              = BUNDLE_ID
  s["PRODUCT_NAME"]                           = "$(TARGET_NAME)"
  s["DEVELOPMENT_TEAM"]                       = TEAM
  s["IPHONEOS_DEPLOYMENT_TARGET"]             = IOS_MIN
  s["SWIFT_VERSION"]                          = "5.0"
  # An explicit Info.plist, like ShareImport. GENERATE_INFOPLIST_FILE merges
  # it with the INFOPLIST_KEY_* settings, which is what we want: the keys
  # Xcode allowlists come from settings, and NSExtension (which it does NOT
  # allowlist) comes from the file.
  s["GENERATE_INFOPLIST_FILE"]                = "YES"
  s["INFOPLIST_FILE"]                         = "FrijWidget-Info.plist"
  s["INFOPLIST_KEY_CFBundleDisplayName"]      = "Frij"
  s["INFOPLIST_KEY_NSHumanReadableCopyright"] = ""
  s["SKIP_INSTALL"]                           = "YES"
  s["TARGETED_DEVICE_FAMILY"]                 = "1,2"
  s["CODE_SIGN_STYLE"]                        = "Automatic"
  s["SWIFT_EMIT_LOC_STRINGS"]                 = "YES"
  s["MARKETING_VERSION"]                      = "1.0.4"
  s["CURRENT_PROJECT_VERSION"]                = "22"
end

# WidgetKit + SwiftUI
%w[WidgetKit SwiftUI].each do |fw|
  ref = project.frameworks_group.new_file("System/Library/Frameworks/#{fw}.framework")
  ref.source_tree = "SDKROOT"
  widget.frameworks_build_phase.add_file_reference(ref)
end

# The extension has to be embedded in the app, and built before it.
app_target.add_dependency(widget)
embed = app_target.build_phases.find do |ph|
  ph.respond_to?(:name) && ph.name == "Embed Foundation Extensions"
end
embed ||= begin
  ph = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  ph.name = "Embed Foundation Extensions"
  ph.symbol_dst_subfolder_spec = :plug_ins
  app_target.build_phases << ph
  ph
end
build_file = embed.add_file_reference(widget.product_reference)
build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

project.save
puts "Added #{TARGET} (#{BUNDLE_ID}) and embedded it in #{APP}."
