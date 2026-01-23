#!/usr/bin/env ruby
# Script to add new Swift files to the Xcode project
# Requires: gem install xcodeproj

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../apps/ios/RoundCaddy.xcodeproj', __dir__)
IOS_SOURCE_PATH = File.expand_path('../apps/ios/GolfStats/Sources', __dir__)
WATCH_SOURCE_PATH = File.expand_path('../apps/watch/RoundCaddyWatch WatchKit Extension/Sources', __dir__)

# Files to add to iOS target
IOS_FILES = {
  'Managers' => %w[
    AICaddieManager.swift
    ARBodyTrackingManager.swift
    DataImportManager.swift
    GracePeriodManager.swift
    HealthKitManager.swift
    LiDARCapabilities.swift
    OfflineCacheManager.swift
    PoseDetector.swift
    SiriIntentsManager.swift
    SwingAnalyzerIOS.swift
    WatchSwingSync.swift
  ],
  'Models' => %w[
    RangeModeModels.swift
    RoundModeConfig.swift
  ],
  'Views' => %w[
    ARCourseView.swift
    CourseNotesView.swift
    FullScreenRoundView.swift
    LiDAR3DView.swift
    RangeModeView.swift
    RangeSessionSummaryView.swift
    RoundModeSelectionView.swift
    SwingReplayView.swift
  ],
  'Components' => %w[
    AdaptiveLayouts.swift
    UIComponents.swift
  ]
}

# Files to add to Watch target
WATCH_FILES = {
  '' => %w[
    ComplicationController.swift
    HapticManager.swift
    RangeModeManager.swift
    WatchIntents.swift
  ],
  'Views' => %w[
    AICaddieWatchView.swift
    HoleNotesWatchView.swift
    RangeModeWatchView.swift
  ]
}

def main
  puts "Opening Xcode project: #{PROJECT_PATH}"
  project = Xcodeproj::Project.open(PROJECT_PATH)

  # Find targets
  ios_target = project.targets.find { |t| t.name == 'RoundCaddy' }
  watch_target = project.targets.find { |t| t.name == 'RoundCaddyWatch' }

  unless ios_target
    puts "ERROR: Could not find 'RoundCaddy' target"
    exit 1
  end

  unless watch_target
    puts "ERROR: Could not find 'RoundCaddyWatch' target"
    exit 1
  end

  # Find or create groups
  ios_sources_group = find_or_create_group(project, 'GolfStats/Sources')
  watch_sources_group = find_or_create_group(project, 'apps/watch/RoundCaddyWatch WatchKit Extension/Sources')

  added_count = 0
  skipped_count = 0

  # Add iOS files
  puts "\n📱 Adding iOS files..."
  IOS_FILES.each do |folder, files|
    group = find_or_create_subgroup(ios_sources_group, folder)
    
    files.each do |filename|
      file_path = File.join(IOS_SOURCE_PATH, folder, filename)
      
      unless File.exist?(file_path)
        puts "  ⚠️  File not found: #{file_path}"
        next
      end

      # Check if already in project
      if file_already_in_project?(project, file_path)
        puts "  ⏭️  Already in project: #{folder}/#{filename}"
        skipped_count += 1
        next
      end

      # Add file reference
      file_ref = group.new_file(file_path)
      ios_target.source_build_phase.add_file_reference(file_ref)
      puts "  ✅ Added: #{folder}/#{filename}"
      added_count += 1
    end
  end

  # Add Watch files
  puts "\n⌚ Adding Watch files..."
  WATCH_FILES.each do |folder, files|
    group = folder.empty? ? watch_sources_group : find_or_create_subgroup(watch_sources_group, folder)
    
    files.each do |filename|
      subfolder = folder.empty? ? '' : folder
      file_path = File.join(WATCH_SOURCE_PATH, subfolder, filename)
      
      unless File.exist?(file_path)
        puts "  ⚠️  File not found: #{file_path}"
        next
      end

      # Check if already in project
      if file_already_in_project?(project, file_path)
        puts "  ⏭️  Already in project: #{folder.empty? ? filename : "#{folder}/#{filename}"}"
        skipped_count += 1
        next
      end

      # Add file reference
      file_ref = group.new_file(file_path)
      watch_target.source_build_phase.add_file_reference(file_ref)
      puts "  ✅ Added: #{folder.empty? ? filename : "#{folder}/#{filename}"}"
      added_count += 1
    end
  end

  # Save project
  puts "\n💾 Saving project..."
  project.save

  puts "\n✨ Done!"
  puts "   Added: #{added_count} files"
  puts "   Skipped: #{skipped_count} files (already in project)"
  puts "\nYou can now open Xcode and build (Cmd+B)"
end

def find_or_create_group(project, path)
  parts = path.split('/')
  group = project.main_group
  
  parts.each do |part|
    found = group.groups.find { |g| g.name == part || g.path == part }
    if found
      group = found
    else
      group = group.new_group(part)
    end
  end
  
  group
end

def find_or_create_subgroup(parent_group, name)
  return parent_group if name.nil? || name.empty?
  
  existing = parent_group.groups.find { |g| g.name == name || g.path == name }
  return existing if existing
  
  parent_group.new_group(name)
end

def file_already_in_project?(project, file_path)
  project.files.any? { |f| f.real_path.to_s == file_path }
end

# Run
main
