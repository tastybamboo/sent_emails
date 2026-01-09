# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails do
  it "has a version number" do
    expect(SentEmails::VERSION).not_to be nil
  end
end
