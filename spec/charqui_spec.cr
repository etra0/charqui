require "./spec_helper"

describe Charqui do
  it "Should parse ratio correctly" do
    cli = Charqui::CLI.new
    cli.parse_ratio "1:1"
    cli.ratio.should eq(0.5)

    cli.parse_ratio "80:20"
    cli.ratio.should eq(0.8)
  end

  it "Should parse sizes correctly" do
    Charqui::SizeKB.parse("10mb").should eq(10 * 1024)
    Charqui::SizeKB.parse("10Mb").should eq(10 * 1024)
    Charqui::SizeKB.parse("10MB").should eq(10 * 1024)
    Charqui::SizeKB.parse("10KB").should eq(10)
    Charqui::SizeKB.parse("10kB").should eq(10)
    Charqui::SizeKB.parse("1GB").should eq(1 * 1024 * 1024)
  end
end
