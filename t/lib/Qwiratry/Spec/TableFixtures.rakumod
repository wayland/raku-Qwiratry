#| Shared table fixtures for t/spec (Operators.md §5.2 / §5.3)
unit module Qwiratry::Spec::TableFixtures;

use Qwiratry::Table;

our sub orders-rows() is export {
	[
		%(order_id => 1, customer_id => 10, total => 100),
		%(order_id => 2, customer_id => 20, total => 50),
		%(order_id => 3, customer_id => 10, total => 75),
		%(order_id => 4, customer_id => Nil, total => 25),
	]
}

our sub customers-rows() is export {
	[
		%(customer_id => 10, name => 'Alice'),
		%(customer_id => 20, name => 'Bob'),
		%(customer_id => 30, name => 'Carol'),
	]
}

#| Returns %( :@orders, :@customers, :$catalog ) with identical row objects.
our sub orders-customers-setup() is export {
	my @orders = orders-rows();
	my @customers = customers-rows();
	my $catalog = make-catalog(
		:orders(@orders), :customers(@customers),
		:foreign-keys(
			ForeignKey.new(
				:from-table('orders'), :from-column('customer_id'),
				:to-table('customers'), :to-column('customer_id'),
			),
		),
		:active-table('orders'),
	);
	%( :@orders, :@customers, :$catalog )
}

#| Returns %( :@orders, :$catalog ) for ordered-row / sibling navigation.
our sub orders-only-setup() is export {
	my @orders = orders-rows();
	my $catalog = make-catalog(:orders(@orders), :active-table('orders'));
	%( :@orders, :$catalog )
}
