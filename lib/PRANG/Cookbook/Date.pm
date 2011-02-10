
package PRANG::Cookbook::Date;
BEGIN {
  $PRANG::Cookbook::Date::VERSION = '0.14';
}

use Moose;
use PRANG::Graph;
use PRANG::Cookbook::Role::Date;

with 'PRANG::Cookbook::Role::Date', 'PRANG::Cookbook::Node';

1;
