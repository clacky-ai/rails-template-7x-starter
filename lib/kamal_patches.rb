# frozen_string_literal: true

# Kamal Monkey Patches
#
# This file loads all monkey patches for the Kamal gem to add custom functionality
# without modifying the gem itself. All patches are version controlled with the project.
#
# Features added:
# - Custom builder name support: Allows specifying pre-configured builders with custom BuildKit configs
#
# Usage:
#   Load before running Kamal commands via:
#   - bin/kamal wrapper script (recommended)
#   - RUBYOPT="-r./lib/kamal_patches" kamal build push
#   - .kamal/hooks/pre-connect hook
#
require_relative 'kamal_patches/configuration_docs_builder_patch'  # Load validator patch first
require_relative 'kamal_patches/configuration_builder_patch'
require_relative 'kamal_patches/commands_builder_remote_patch'
