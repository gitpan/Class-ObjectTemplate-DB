package Class::ObjectTemplate::DB;
use Class::ObjectTemplate ();
use Carp;
require Exporter;

use vars qw(@ISA @EXPORT $VERSION $DEBUG);

@ISA = qw(Class::ObjectTemplate Exporter);
@EXPORT = qw(attributes);
$VERSION = 0.22;

$DEBUG = 0; # assign 1 to it to see code generated on the fly 

# JES -- Added to be able to turn automatic lookup on and off at
# method definition time. Set this to be true before calling
# attributes and the getter method will call undefined() if the
# current value is 'undef'.

# Create accessor functions, and new()
#
# attributes(lookup => ['foo', 'bar'], no_lookup => ['baz'])
# attributes('foo', 'bar', 'baz')
#
sub attributes {
    my ($pkg) = caller;

    croak "Error: attributes() invoked multiple times" 
      if scalar @{"${pkg}::_ATTRIBUTES_"};

    my %args;
    # figure out if we were called with a simple parameter list
    # or with a hash-style parameter list
    if (scalar @_ % 2 == 0 &&
	($_[0] eq 'lookup' || $_[0] eq 'no_lookup') &&
	ref($_[1]) eq 'ARRAY') 
    {
      # we were called with hash style parameters
      %args = @_;
    } else {
      # we were called with a simple parameter list
      %args = ('no_lookup' => [@_]);
    }

    my $code = "";
    my $lookup;
    print STDERR "Creating methods for $pkg\n" if $DEBUG;
    foreach my $key (keys %args) {
      push(@{"${pkg}::_ATTRIBUTES_"},@{$args{$key}});

      # set up the $lookup boolean
      $lookup = ($key eq 'lookup');
      foreach my $attr (@{$args{$key}}) {
	print STDERR "  defining method $attr\n" if $DEBUG;

        # If a field name is "color", create a global list in the
        # calling package called @_color
        @{"${pkg}::_$attr"} = ();

        # If the accessor is already present, give a warning
        if (UNIVERSAL::can($pkg,"$attr")) {
	  carp "$pkg already has method: $attr";
	}
	$code .= _define_accessor ($pkg, $attr, $lookup);
      }
    }

    # Define accessor only if we haven't done it already. This enables
    # attributes() to be called multiple times.
    unless (UNIVERSAL::can($pkg,"new")) {
      print STDERR "defining constructor for $pkg\n" if $DEBUG;
      $code .= Class::ObjectTemplate::_define_constructor($pkg);
    } else {
      print STDERR "constructor already defined for $pkg\n" if $DEBUG;
    }
    eval $code;
    if ($@) {
       die  "ERROR defining constructor and attributes for '$pkg':" 
            . "\n\t$@\n" 
            . "-----------------------------------------------------"
            . $code;
    }
}

sub _define_accessor {
    my ($pkg, $attr, $lookup) = @_;

    # This code creates an accessor method for a given
    # attribute name. This method  returns the attribute value 
    # if given no args, and modifies it if given one arg.
    # Either way, it returns the latest value of that attribute

    # JES -- modified to first call function undefined() if the getter
    #   is called and the current value is undef

    # JES -- fixed bug where getter was called with foo(undef)
    #   added 'return' to setter line

    # JES -- fixed bug so that inherited classes worked

    # JES -- simplified the free list to be a stack, and added a 
    # separate $_max_id variable

    my $code;
    if ($lookup) {
      # If we are to do automatic lookup when the current value
      # is undefined, we need to be complicated
      $code = qq{
        package $pkg;
        sub $attr {                                       # Accessor ...
            my \$name = ref(\$_[0]) . "::_$attr";
            return \$name->[\${\$_[0]}] = \$_[1] if \@_ > 1; # set
            return \$name->[\${\$_[0]}] 
                 if defined \$name->[\${\$_[0]}];     # get
	    # else call undefined(), and give it a change to define
            return \$name->[\${\$_[0]}] = \$_[0]->undefined('$attr');
        }
      };
    } else {
      # if we don't need to do lookup, it's short and sweet
      $code = qq{
        package $pkg;
        sub $attr {                                      # Accessor ...
            my \$name = ref(\$_[0]) . "::_$attr";
            \@_ > 1 ? \$name->[\${\$_[0]}] = \$_[1]  # set
                    : \$name->[\${\$_[0]}];          # get
        }
      };
    }
    $code .= qq{
        if (!defined \$max_id) {
            # Set up the free list, and the ID counter
            \@_free = ();
            \$_max_id = 0;
        };
    };
    $code;
}

# JES
# default function for lookup. Does the obvious
sub undefined {return undef;}
1;

