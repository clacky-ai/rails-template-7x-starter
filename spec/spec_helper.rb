FAIL_FAST_LIMIT = 3

RSpec.configure do |config|
  config.fail_fast = FAIL_FAST_LIMIT

  at_exit do
    failed_count = RSpec.configuration.reporter.failed_examples.count
    if failed_count >= FAIL_FAST_LIMIT && RSpec.world.wants_to_quit
      puts "\n" + "=" * 80
      puts "⚠️  Stopped after #{failed_count} failures (fail_fast limit reached)"
      puts "💡 Fix these errors first, then run the full test suite to find remaining issues"
      puts "=" * 80
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
