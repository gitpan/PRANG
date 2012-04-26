
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Moose XML Processor",
  "AUTHOR" => "Catalyst SRS Team <team-srs\@catalyst.net.nz>",
  "BUILD_REQUIRES" => {
    "Scriptalicious" => "1.16",
    "XML::Compare" => "0.04",
    "YAML" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "PRANG",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "PRANG",
  "PREREQ_PM" => {
    "JSON" => "2.50",
    "Moose" => "1.21",
    "MooseX::Params::Validate" => "0.15",
    "Set::Object" => "1.09",
    "XML::LibXML" => "1.65"
  },
  "VERSION" => "0.15",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



