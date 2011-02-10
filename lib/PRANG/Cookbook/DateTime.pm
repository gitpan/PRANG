
package PRANG::Cookbook::DateTime;
BEGIN {
  $PRANG::Cookbook::DateTime::VERSION = '0.13';
}

use Moose;
use PRANG::Graph;

use PRANG::Cookbook::Role::Date;
use PRANG::Cookbook::Role::Time;

with 'PRANG::Cookbook::Role::Date', 'PRANG::Cookbook::Role::Time',
	'PRANG::Cookbook::Node';

1;
