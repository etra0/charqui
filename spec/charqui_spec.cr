require "./spec_helper"

describe Charqui do
  # TODO: Write tests

  it "Should parse ratio correctly" do
    cli = Charqui::CLI.new
    cli.parse_ratio "1:1"
    cli.ratio.should eq(0.5)
  end
end
