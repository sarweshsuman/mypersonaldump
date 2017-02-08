# ##########################################################################
# MODULENAME          : PMTExecContext;
# AUTHOR              : Evert Carton
# INPUTS              : NONE
# OUTPUTS             : NONE
# DEPENDENCY          : NONE
# REMARKS             : NONE
# VERSION             : 1.0
# REVISION HISTORY    : Initial Version
# ##########################################################################

# ==========================================================================
#
# Package Declaration
#
# ==========================================================================

package PMTExecContext;

# ==========================================================================
#
# Use Declarations 
#
# ==========================================================================

use strict;
use PMTStackedDataHandler;
use Carp;

use PMTUtilities qw(icdefined partial);

use overload '%{}' => \&handleparameters,
             '""'  => \&asstring,
             '>>'  => \&merge
;

# ==========================================================================
#
# Constructor
# 
# ==========================================================================

sub new {
  my $class=shift;
  my $object = {};
  my $controller = shift;

  my $_delegate = undef;
  if (defined $controller and ref $controller eq __PACKAGE__) {
    $_delegate = $controller;
  }
  
  my $_helpers_ = [$controller];
  my $_namedhelpers_ = {CONTROLLER=>$controller};
  my $_garbagecleanup_actions = [];
  my $_garbagecleanup_directives = {};
  my $_garbagecleanup_labels = [];
  my $_jobparameters_ = {};
  my $_outrunjobreturnparameters_ = {};
  my $_interceptors_ = [];
  my $_plugins_ = [];
  my $_namedinterceptors_ = {};
  my $_namedplugins_ = [];
  my $_interceptors_started_ = 0;
  my $_jobstartlevel_ = [];

  # A few forward declarations ...
  my $operations; # a forward declaration
  my %stacked_parameters;
  my $stackeddatahandler;

  my $closure = sub {
    my $operation = shift;
    $operation = $operations->{$operation};
    if (not defined $operation) {
      print STDERR "operation $operation not supported\n";
    }
    return &$operation(@_);
  };

# -------------------------------------------
#
# Implamentation of exported methods
#
# -------------------------------------------
  $operations = {

    setparameters => sub {
      print STDERR "doing setparameters\n";
      print STDERR "Argslength:",scalar @_,"\n";
    },

    getparameters => sub {
      print STDERR "doing getparameters\n";
    },
  
    GETMASTER => sub {
      return $_delegate;
    },

    RETURN_STACKED_HASH => sub {
      my %args = @_;
     	return \%stacked_parameters;
    },

    ADDPLUGIN => sub {
      my %args = @_;
      if (not defined $args{'name'} and not defined $args{'plugin'}) {
        croak { message=>"Invalid arguments to addPlugin method in PMTExecContext"};
      }
      my $initparams=$args{'initparams'};
      my $plugin = $args{'plugin'};

      if (defined $args{'name'}) {
        my $name = uc $args{'name'};
        if (grep { $_->{'name'} eq $name} @$_namedplugins_) { # exists $_namedplugins_->{$name}){
          if ($args{'ignoreduplicate'}) {
            # This is OK, nothing needs to be done here ...
          }
          else {
            croak { message=>"A plugin is allready registered under the name $args{name}"};
          }
        }
        else {
          if (not defined $plugin) {
            my $modname = undef;
            if (defined $args{'module'}) {
               $modname = $args{'module'};
            }
            else {
              my $configname = "PLUGINMODULE_$name";
              eval {
                # It is possible that the logger is not added yet ...
                $closure->log(call_level=>1,domain=>"lifecycle",level=>"trace",message=>"Trying to find module for $name, using configname $configname");
              };
              $modname = $closure->getConfigParameter($configname);
            }

						if (not defined $modname) {
							if (defined $args{'defaultmodule'}) {
								$modname = $args{'defaultmodule'};
							}
							else {
								croak {message=>"Could not determine a valid modulename for plugin $name",job_stat=>'FATAL9'};
							}
						}

						eval {
							$closure->log(call_level=>1,domain=>"lifecycle",level=>"trace",message=>"Got module name $modname for plugin $name");
						};

						eval "require $modname;" or croak {message=>"Could not load module $modname for plugin name $name"};
						eval { import $modname;};
						croak {message=>$@} if $@;

            my $constructorsubref = "${modname}::new";
            my $constructorsub = \&{$constructorsubref};
            use Data::Dumper;
            if (defined $constructorsub) {
              eval {
                $plugin = new $modname(initialcontext=>$closure,name=>$name,initparams=>$initparams);
                if ($plugin->isa('PMTHelperBase')) {
                   #print STDERR "$plugin is a helper\n";
                   $closure->addHelper(name=>$name,helper=>$plugin);
                   #push @$_namedplugins_, { name=>uc $name, plugin=> $plugin,type=>'HELPER' };
                }
                if ($plugin->isa('PMTInterceptorBase')) {
                   #print STDERR "$plugin is an interceptor\n";
                   $closure->addInterceptor(name=>$name,interceptor=>$plugin);
                   #$_namedplugins_->{uc $name} = $plugin;
                   #push @$_namedplugins_, { name=>uc $name, plugin=> $plugin,type=>'INTERCEPTOR' };
                }
                if ($plugin->isa('PMTHelperBase') or $plugin->isa('PMTInterceptorBase')) {
                  my @types = ();
                  if ($plugin->isa('PMTHelperBase')) { push @types,'HELPER'; }
                  if ($plugin->isa('PMTInterceptorBase')) { push @types,'INTERCEPTOR'; }
                  push @$_namedplugins_, { name=>uc $name, plugin=> $plugin,type=>\@types };
                }
                else {
                   croak { message=>"Plugin $name is of unknown type" };
                } 
              };
              if ($@) { croak { message=>"Failed to load plugin $name: ". Dumper($@) }; }
            }
            else {
              croak { message=>"Could not find reference to constructor in module $modname" };
            }
          }
          else { # plugin is defined 
            #print STDERR "Adding a plugin and the plugin is a plugin: $plugin\n";
            if ($plugin->isa('PMTHelperBase')) {
              #print STDERR "$plugin is a helper\n";
              $closure->addHelper(name=>$name,helper=>$plugin);
              #push @$_namedplugins_, { name=>uc $name, plugin=> $plugin,type=>'HELPER' };
            }
            if ($plugin->isa('PMTInterceptorBase')) {
              #print STDERR "$plugin is an interceptor\n";
              $closure->addInterceptor(name=>$name,interceptor=>$plugin);
              #$_namedplugins_->{uc $name} = $plugin;
              #push @$_namedplugins_, { name=>uc $name, plugin=> $plugin,type=>'INTERCEPTOR' };
            }
						if ($plugin->isa('PMTHelperBase') or $plugin->isa('PMTInterceptorBase')) {
							my @types = ();
							if ($plugin->isa('PMTHelperBase')) { push @types,'HELPER'; }
							if ($plugin->isa('PMTInterceptorBase')) { push @types,'INTERCEPTOR'; }
							push @$_namedplugins_, { name=>uc $name, plugin=> $plugin,type=>\@types };
						}
            else {
              #print STDERR "This plugin is of an unknown type\n";
            }
          }
          push (@{$_plugins_},$plugin);
        }
      }
      else {
        push (@{$_plugins_},$plugin);
      }
    },

    HASNAMEDPLUGIN => sub {
      my %args = @_;
      my $name = $args{'name'};
      #print "Checking for name $name\n";
      my @p = @{$_namedplugins_};
      my @p2 = map { $_->{'name'} } @p;
      use Data::Dumper; 
      #print STDERR Dumper(\@p2),"\n";
      my @p3 = grep (/$name/i,@p2);
      #print STDERR "p3:",Dumper(\@p3),"\n";

      if (scalar @p3 gt 0) {
        return 1;
      }
      else {
        return 0;
      }
    },

    GETNAMEDPLUGINS => sub {
      my %args = @_;
      my $type = $args{'type'};
      my $name = $args{'name'};

      if (defined $type) { $type = uc $type; }
      if (defined $name) { $name = uc $name; }

      my @p = @{$_namedplugins_};
      if (defined $type) { 
        my @tp = ();
        for my $pl (@p) {
           my $ttp = $pl->{'type'};
           if (grep /$type/,@$ttp) {
             push @tp,$pl;
           }
        }
        @p = @tp;
      }
      if (defined $name) { @p = grep { $_->{'name'} eq $name } @p; }
      
      my @p2 = map { { name=>$_->{'name'},plugin=>$_->{'plugin'}} } @p;
      return \@p2;

      return $_namedplugins_;
    },

    NUMBEROFLEVELS => sub {
      return $stackeddatahandler->getNumberOfLevels();
    },

    FREEZE => sub {
      # add a new level
      my $startstack = $stackeddatahandler->addParameterStack();
      my $numberoflevels = $stackeddatahandler->getNumberOfLevels();
      # make this the bottom level
      push(@{$_jobstartlevel_},$numberoflevels);
    },

    ICEXPORT => sub {
      my %args = @_;
      my $startlevel;
      if (defined $args{'fromlevel'}) {
        $startlevel = $args{'fromlevel'};
      }
      else {
        $startlevel = pop @{$_jobstartlevel_};
      }
      
      my $rv = $stackeddatahandler->exportProcessImage(fromlevel=>$startlevel);
      return $rv;
    },

    COALESCE => sub {
      my @args = @_;
      # Try all the values in a row
      for my $a (@args) {
        my $v = $closure->{$a};
        if (icdefined $v) {
          return $v;
        }
      }
      my $none = {};
      $none->{'__DYNAMIC__'} = 1;
      bless $none,'VOID';
      return $none;
    },

    EXPAND => sub {
      my $value = shift;
      if (ref $value eq 'HASH') {
        my $rv = {};
        for my $k (keys %$value) {
          my $expkey = $closure->expand($k);
          my $vtoe = $value->{$k};
          if (not defined $vtoe) {
            $rv ->{$expkey} = $vtoe;
          }
          if (not ref $vtoe and $vtoe =~m/^\{!(.*)!\}$/) {
            $vtoe = $closure->resolve($1);
            $rv->{$expkey} = $vtoe;
          }
          #elsif (not ref $vtoe and $vtoe =~m/^\{\{(.*)\}\}$/) {
          elsif (not ref $vtoe and $vtoe =~m/\{\{(.*)\}\}/) {
            $vtoe = PMTUtilities::expand(src=>$vtoe,evalcontext=>$closure,nokeysplit=>1);
            $rv->{$expkey} = $vtoe;
          }
          else {
            $rv->{$expkey} = $closure->expand($vtoe);
          }
          
          #print "value to expand = ",$value->{$k},"which is a ref ",ref  $value->{$k},"\n";
          #my $resval = $closure->resolve($value->{$k});
          #print "expandedvalue = ",$resval,"which is a ref ",ref  $resval,"\n";
          #$rv->{$expkey} = $closure->expand($value->{$k});
        }
        return $rv;
      }
      elsif (ref $value eq 'ARRAY') {
  			my @rvalue = ();
  			for my $localval (@$value) {
    			my $lllooocccaaalllvvvaaallluuueee = $closure->expand($localval);
    			push (@rvalue,$lllooocccaaalllvvvaaallluuueee);
  			}
  			return \@rvalue;
      }
      elsif (not ref $value) {
        my $rv = $value;
        if ($rv =~m/^\{!(.*)!\}$/) {
    			$rv = $closure->resolve($1);
      	}
        my $lrv = PMTUtilities::expand(src=>$rv,evalcontext=>$closure,nokeysplit=>1);
        return $lrv;
      }
      else {
        return $value;
      }
    },

    RESOLVE => sub {
      my @args = @_;
      for my $a (@args) {
        ## First test if it needs to be expanded first
        $a =~ s/!\}$//;
        $a =~ s/^\{!//;
        #print STDERR "in resolve I should be expanding $a\n";
        $a = PMTUtilities::expand(src=>$a,evalcontext=>[$closure],nokeysplit=>1);
        #print STDERR "in resolve, really looking for $a\n";
        my $v = $closure->{$a};
        
        if (icdefined $v) {  # It does exist
          if (not ref $v) {  # It is a scalar
            my $res = undef;
            eval {
              my $v2 = PMTUtilities::expand(src=>$v,evalcontext=>$closure,nokeysplit=>1);
              # Since returning in an eval-block doesn't work as one would expect ...
              $res = $v2;
            };
            if (defined $res) {
              return $res;
            }
          }
          else {
            return $v;
          }
        }
        else {
          #print STDERR "resolve did not find anything\n";
        }
      }
      return undef;
    },

    STARTINTERCEPTORS => sub {
      my %args = @_;
      #if (scalar @$_interceptors_ == 0) {
      #  my $interceptors_to_load = $closure->getConfigParameter('LOADINTERCEPTORS');
      #
      #  if (defined $interceptors_to_load && $interceptors_to_load eq '_NONE_') {
      #    $interceptors_to_load = undef;
      #  }
      #  if (defined $interceptors_to_load) {
      #    if (ref $interceptors_to_load eq 'ARRAY') {
      #      # life is goed
      #    }
      #    else {
      #      $interceptors_to_load = [$interceptors_to_load];
      #    }
      #  }
      #  if (not defined $interceptors_to_load) {
      #    $interceptors_to_load = [];
      #  }
      #
      #  for my $itl (@$interceptors_to_load) {
      #    $closure->addInterceptor(name=>$itl,ignoreduplicate=>1);
      #  }
      #}
      $_interceptors_started_ = 1;
      $stackeddatahandler->startInterceptors();
    },

    STOPINTERCEPTORS => sub {
      $_interceptors_started_ = 0;
      $stackeddatahandler->stopInterceptors();
    },

    GETNAMEDHELPER => sub {
      my %args = @_;
      my $name = uc $args{'name'};
      return $_namedhelpers_->{$name};
    },

    GETNAMEDPLUGIN => sub {
      my %args = @_;
      my $name = uc $args{'name'};
      my @named_plugins = @{$_namedplugins_};

      my @searchp = grep { $_->{'name'} eq uc $name } @{$_namedplugins_};
      if (@searchp) {
        return $searchp[0]->{'plugin'};
      }
      return undef;
    },

    ADDINTERCEPTOR => sub {
      my %args = @_;
      if (not defined $args{'name'} and not defined $args{'interceptor'}) {
        croak { message=>"Invalid arguments to addInterceptor method in PMTExecContext"};
      }

      my $interceptor = $args{'interceptor'};


      if (defined $args{'name'}) {
        my $name = uc $args{'name'};
        if (exists $_namedinterceptors_->{$name}){
          if ($args{'ignoreduplicate'}) {
            # This is OK, nothing needs to be done here ...
          }
          else {
            croak { message=>"An interceptor is allready registered under the name $args{name}"};
          }
        }
        else {
          if (not defined $interceptor) {
            my $configname = "INTERCEPTORMODULE_$name";
            eval {
              # It is possible that the logger is not added yet ...
            $closure->log(call_level=>1,domain=>"lifecycle",level=>"trace",message=>"Trying to find module for $name, using configna
me $configname");
            };
            my $modname = $closure->getConfigParameter($configname);
            if (not defined $modname) {
              if (defined $args{'defaultmodule'}) {
                $modname = $args{'defaultmodule'};
              }
              else {
                croak {message=>"Could not determine a valid modulename for interceptor $name",job_stat=>'FATAL9'};
              }
            }
            eval {
            $closure->log(call_level=>1,domain=>"lifecycle",level=>"trace",message=>"Got module name $modname for interceptor $name");
            };
            eval "require $modname;" or croak {message=>"Could not load module $modname for interceptor name $name"};
            eval { import $modname;};
            croak {message=>$@} if $@;
            my $constructorsubref = "${modname}::new";
            my $constructorsub = \&{$constructorsubref};
            if (defined $constructorsub) {
              eval {
                $interceptor = new $modname(initialcontext=>$closure,name=>$name);
              };
            }
            else {
              print STDERR "could not find reference to constructor in module $modname\n";
            }
          }
          $_namedinterceptors_->{$name} = $interceptor;
          if (defined $interceptor and $interceptor->can('setModuleConfigName')) {
            eval {
            $interceptor->setModuleConfigName($name);
            };
            if ($@) { print STDERR "An error occurred while setting moduleconfigname: $@->{'message'}\n"; }
          }
          push (@{$_interceptors_},$interceptor);
          $stackeddatahandler->addInterceptor($interceptor);
        }
      }
      else {
        push (@{$_interceptors_},$interceptor);
        $stackeddatahandler->addInterceptor($interceptor);
      }
    },


    ADDHELPER => sub {
      my %args = @_;
      if (not defined $args{'name'} and not defined $args{'helper'}) {
        croak { message=>"Invalid arguments to addHelper method in PMTExecContext"};
      }
      my $helper = $args{'helper'};
      
      if (defined $args{'name'}) {
        my $name = uc $args{'name'};
        if (exists $_namedhelpers_->{$name}){
          if ($args{'ignoreduplicate'}) {
            # This is OK, nothing needs to be done here ... 
          }
          else {
            croak { message=>"A helper is allready registered under the name $args{name}"};
          }
        }
        else {
          if (not defined $helper) {
            my $configname = "HELPERMODULE_$name";
            eval {
              # It is possible that the logger is not added yet ... 
            $closure->log(call_level=>1,domain=>"lifecycle",level=>"trace",message=>"Trying to find module for $name, using configname $configname");
            };
            my $modname = $closure->getConfigParameter($configname);
            if (not defined $modname) {
              if (defined $args{'defaultmodule'}) {
                $modname = $args{'defaultmodule'};
              }
              else {
                croak {message=>"Could not determine a valid modulename for helper $name",job_stat=>'FATAL9'};
              }
            }
            eval {
            $closure->log(call_level=>1,domain=>"lifecycle",level=>"trace",message=>"Got module name $modname for helper $name");
            };
            eval "require $modname;" or croak {message=>"Could not load module $modname for helper name $name"};
            eval { import $modname;};
            croak {message=>$@} if $@;
            my $constructorsubref = "${modname}::new";
            my $constructorsub = \&{$constructorsubref};
            if (defined $constructorsub) {
              eval {
                $helper = new $modname(initialcontext=>$closure,name=>$name);
              };
            }
            else {
              print STDERR "could not find reference to constructor in module $modname\n";
            }
          }
          $_namedhelpers_->{$name} = $helper;
          if (defined $helper and $helper->can('setModuleConfigName')) {
            $helper->setModuleConfigName($name);
          }
          push (@{$_helpers_},$helper);
        }
      }
      else {
        push (@{$_helpers_},$helper);
      }
    },

    AUTOLOADER => sub {

      my $method = shift;
      my $named_helper;
      #print STDERR "L60EXECCONTEXT:Looking for $method\n";
      if ($method =~ m/^_([^_]+)_(.+)/) {
        $named_helper = uc $1;
        $method = $2;
        #print STDERR "L60EXECCONTEXT: Looking for method $method in named_helper $named_helper\n";
        if (defined $_namedhelpers_->{$named_helper}) {
          my $h = $_namedhelpers_->{$named_helper};
          if ($h->can('pluginHasHelperMethod')) {
            my $v = $h->pluginHasHelperMethod(method=>$method);
            if ($v) {
              my $hm = $h->can($method);
              return $h->$hm(@_);
            }
          }
          elsif ($h->can($method)) {
            my $hm = $h->can($method);
            if ($method eq 'log') {
              return $h->$hm(_CALL_LEVEL_=>2,@_);
            }
            else {
              return $h->$hm(@_);
            }
          }
          elsif ($h->can('isSupportedDynamicMethod') and $h->isSupportedDynamicMethod(method=>$method)) {
            #print STDERR "Found supported Dynamic Method: $method\n";
            return $h->runSupportedDynamicMethod(method=>$method,args=>\@_);
          }
          else {
            $named_helper = undef;
          }
        }
      }


      if (defined $named_helper) {
        # Wait a minute
        # Damn, what was the wait a minute about
      }
      else {
        my @helpers=@{$_helpers_};
        @helpers = reverse @helpers;
        my $meth;
        foreach my $hp (@helpers) {
          my $r;
          $meth = undef;
          if (defined $hp) {
						if ($hp->can('pluginHasHelperMethod')) {
							my $v = $hp->pluginHasHelperMethod(method=>$method);
							if ($v) {
								return $hp->$method(@_);
							}
						}
            else {
            	$meth=$hp->can($method);
            	if ($meth) {
              	return $hp->$method(@_);
            	}
            }
            return $r if defined $meth;
          }
        }
        print STDERR "Parameters for UNFOUND method $method : @_\n";
        croak {message=>"Could not determine helper for method $method",job_stat=>'FATAL9'};
      }
    },

    ADDGARBAGECLEANUPHANDLER => sub {
      my %args = @_;
      push (@{$_garbagecleanup_actions},\%args);
    },
    CLEARGARBAGECLEANUPHANDLERS => sub {
      $_garbagecleanup_actions = [];
    },
    HANDLEGARBAGECLEANUPHANDLERS => sub {
      my %args = @_;
      my @gh = @$_garbagecleanup_actions; 
      my $exitcode = $args{'exitcode'};
     
      for my $handler (@gh) {
        my $action = $handler->{'action'} ;
        if (not defined $action) {
          return;
        }
        if (defined $handler->{'label'}) {
          eval {
            $closure->log(domain=>"lifecycle",level=>"info",message=>$handler->{'label'});
          };
          if ($@) {
            print STDERR "$@\n";
          }
        }
        if (defined $handler->{'onerror'}) {
          if ($handler->{'onerror'} eq 0) {
            if ($exitcode gt 0) {
              # do nothing
            }
            else {
              #print STDERR "doing cleanup action\n";
              eval { &$action(initialcontext=>$closure); };
            }
          }
          else {
            eval { &$action(initialcontext=>$closure); };
          }
        }
        else {
          eval { &$action(initialcontext=>$closure); };
        }
      }
    },

    ADDPARAMETERSTACK => sub {
      return $stackeddatahandler->addParameterStack();
    },

    POPPARAMETERSTACK => sub {
      return $stackeddatahandler->popParameterStack(@_);
    },

    GETROOTLEVEL => sub {
      return $stackeddatahandler->getRootLevel(@_),
    },
    GETCURRENTLEVEL => sub {
      return $stackeddatahandler->getCurrentLevel(),
    },
    SETROOTPARAMETER => sub {
      my %args = @_;
      my $key = $args{'key'};
      my $value = $args{'value'};
      my $rl = $stackeddatahandler->getRootLevel();
      $rl->{$key} = $value;
      $stackeddatahandler->setNeedsRebuild();
      return $value;
    },
    GETROOTPARAMETER => sub {
      my %args = @_;
      my $key = $args{'key'};
      my $rl = $stackeddatahandler->getRootLevel();
      return $rl->{$key};
    },
    
    GETHELPERBYMETHODNAME => sub {
      my %args = @_;
      my $methodname = $args{'method'};
      my @helpers=@{$_helpers_};
      shift @helpers; # We don't want the first one, which is the controller, if it is defined
      @helpers = reverse @helpers;

      foreach my $hp (@helpers) {
        if (defined $hp) {
          if ($hp->can($methodname)) {
            return $hp;
          }
        }
      }
      return undef;
    },

    SETJOBRETURNPARAMETER => sub {
      my %args = @_;
      my $k = $args{'name'};
      if (not defined $k) {
        $k = $args{'key'};
      }
      my $val = $args{'value'};
      $_outrunjobreturnparameters_->{$k} = $val;
      return undef;
    },

    GETALLOUTRUNJOBRETURNPARAMETERS => sub {
      return {};
      return $_outrunjobreturnparameters_;
    },

    SETJOBPARAMETER => sub {
      # Explicitly set it to the jobparameters
      my %args = @_;
      my $k = $args{'key'};
      my $v = $args{'value'};
      $_jobparameters_->{$k} = $v;
    },

    GETJOBPARAMETER => sub {
      my %args = @_;
      my $k = $args{'key'};
      return $_jobparameters_->{$k};
    },

    GETLAYERDATA => sub {
      return $stackeddatahandler->getLayerData(@_);
    }
  };

  # here we should actually have the interceptors
  # we should clone them from the parent

  bless $closure;

  # The code below is kinda clumsy, it could have been better handled in 
  if (defined $_delegate) {
    
  	$stackeddatahandler = tie (%stacked_parameters,'PMTStackedDataHandler',initialcontext=>$closure);
  	$stackeddatahandler->setRawHash(\%stacked_parameters);
  	$stackeddatahandler->setParent(undef);

    my $src_hash = $_delegate->getRawHash();
    use PMTUtilities qw(mergeRecursiveHash);
    mergeRecursiveHash(src=>$src_hash,update=>$closure);
    
    my $interceptors = $_delegate->getNamedPlugins(type=>'interceptor');


    # we could do the following in one shot I guess, but I did explicitly prefer the two step approach
    my $tmpnames = {};
    for my $iceptor (@$interceptors) {
      if ($iceptor->{'plugin'}->can('isCloneable') and $iceptor->{'plugin'}->isCloneable() and $iceptor->{'plugin'}->can('clone')) { 
      	$tmpnames->{$iceptor->{'name'}} = 1;
      	$closure->addPlugin(name=>$iceptor->{'name'},plugin=>$iceptor->{'plugin'}->clone(initialcontext=>$closure));
      }
      else {
        print STDERR "Not copying interceptor $iceptor->{'name'} because some conditions are not fulfilled\n";
      }
    }

    my $helpers = $_delegate->getNamedPlugins(type=>'HELPER');

    for my $helpe (@$helpers) {
      if (not defined $tmpnames->{$helpe->{'name'}}) {
      	if ($helpe->{'plugin'}->can('doInherit') and $helpe->{'plugin'}->doInherit()) { 
      		$closure->addPlugin(name=>$helpe->{'name'},plugin=>$helpe->{'plugin'});
        }
        #elsif ($helpe->{'plugin'}->can('isCloneable') and $helpe->{'plugin'}->isCloneable() and $helpe->{'plugin'}->can('clone')) {
      	#	$closure->addPlugin(name=>$helpe->{'name'},plugin=>$helpe->{'plugin'}->clone(initialcontext=>$closure));
        #}
      }
    }



    # I should copy the data
    # i should take over the plugins
    # clone the interceptors and simply retain the current plugins as they are 
  }
  else {
  	$stackeddatahandler = tie (%stacked_parameters,'PMTStackedDataHandler',initialcontext=>$closure);
  	$stackeddatahandler->setRawHash(\%stacked_parameters);
  	$stackeddatahandler->setParent(undef);
  }
  return $closure;
}

# ==========================================================================
#
# Methods
#
# ==========================================================================


# --------------------------------------------------------------------------
#
# Operator Overloading methods
#
# --------------------------------------------------------------------------

sub asstring {
  return '<'.__PACKAGE__.' instance>';
}
sub handleparameters {
  my ($self,$k,$v,$rev) = @_;
  return &$self('RETURN_STACKED_HASH');
}

sub getRawHash {
  my $self = shift;
  return &$self('RETURN_STACKED_HASH',@_);
}

sub merge {
  my $self = shift;
  my $other = shift;
  my $order = shift;
  my $r;
  if ($order) {
    $r = PMTUtilities::mergeData (src=>$other,update=>$self,keepdefined=>1);
  }
  else {
    $r = PMTUtilities::mergeData (src=>$self,update=>$other);
  }
  return undef;
}

# --------------------------------------------------------------------------
#
# Regular methods
#
# --------------------------------------------------------------------------

sub addParameterStack {
  my $self = shift;
  return &$self('ADDPARAMETERSTACK',@_);
}

sub getCurrentLevel {
  my $self = shift;
  return &$self('GETCURRENTLEVEL',@_);
}

sub getLayerData {
  my $self = shift;
  return &$self('GETLAYERDATA',@_);
}

sub getRootLevelParameters {
  my $self = shift;
  my $rp = &$self('GETROOTLEVEL');
  my %nrp = %$rp;
  return \%nrp;
}

sub getRootParameter {
  my $self = shift;
  return &$self('GETROOTPARAMETER',@_);
}

sub setRootParameter {
  my $self = shift;
  return &$self('SETROOTPARAMETER',@_);
}

sub getOutParameter {
  my $self = shift;
  return &$self('GETOUTPARAMETER',@_);
}

sub setJobReturnParameter {
  my $self = shift;
  return &$self('SETJOBRETURNPARAMETER',@_);
}

sub setJobParameter {
  my $self = shift;
  return &$self('SETJOBPARAMETER',@_);
}

sub getJobParameter {
  my $self = shift;
  return &$self('GETJOBPARAMETER',@_);
}

sub getAllOutRunJobParameters {
  my $self = shift;
  return &$self('GETALLOUTRUNJOBRETURNPARAMETERS',@_);
}

sub popParameterStack {
  my $self = shift;
  return &$self('POPPARAMETERSTACK',@_);
}

sub addHelper {
  my $self = shift;
  return &$self('ADDHELPER',@_);
}

sub getNamedHelper {
  my $self = shift;
  return &$self('GETNAMEDHELPER',@_);
}

sub getNamedPlugin {
  my $self = shift;
  return &$self('GETNAMEDPLUGIN',@_);
}

sub getNamedPlugins {
  my $self = shift;
  return &$self('GETNAMEDPLUGINS',@_);
}

sub hasNamedPlugin {
  my $self = shift;
  return &$self('HASNAMEDPLUGIN',@_);
}

sub addGarbageCleanupHandler {
  my $self = shift;
  return &$self('ADDGARBAGECLEANUPHANDLER',@_);
}

sub handleGarbageCleanupHandlers {
  my $self = shift;
  return &$self('HANDLEGARBAGECLEANUPHANDLERS',@_);
}

sub clearGarbageCleanupHandlers {
  my $self = shift;
  return &$self('CLEARGARBAGECLEANUPHANDLERS',@_);
}

sub startInterceptors {
  my $self = shift;
  return &$self('STARTINTERCEPTORS',@_);
}

sub stopInterceptors {
  my $self = shift;
  return &$self('STOPINTERCEPTORS',@_);
}

sub addInterceptor {
  my $self = shift;
  return &$self('ADDINTERCEPTOR',@_);
}

sub addPlugin {
  my $self = shift;
  return &$self('ADDPLUGIN',@_);
}

sub getHelperByMethodName {
  my $self = shift;
  return &$self('GETHELPERBYMETHODNAME',@_);
}

sub freeze {
  my $self = shift;
  return &$self('FREEZE',@_);
}

sub exportProcessImage {
  my $self = shift;
  return &$self('ICEXPORT',@_);
}
 
sub getNumberOfLevels {
  my $self = shift;
  return &$self('NUMBEROFLEVELS',@_);
}

sub coalesce {
  my $self = shift;
  return &$self('COALESCE',@_);
}

sub resolve {
  my $self = shift;
  return &$self('RESOLVE',@_);
}

sub expand {
  my $self = shift;
  return &$self('EXPAND',@_);
}

sub createfuncUnitSpec {
  my $self = shift;
  my $funcspec = shift;
  my %paramspec = @_;
  my $rv = {funcspec=>$funcspec,parameters=>\%paramspec};
  bless $rv,'FUNCUNITSPEC';
  return $rv;
}

# --------------------------------------------------------------------------
# 
# The MAGIC AUTOLOADER 
# 
# --------------------------------------------------------------------------

sub AUTOLOAD {
  ## dynamic delegation ... 
  my $self = shift;
  our $AUTOLOAD;
  my $method = (split(/::/,$AUTOLOAD))[1];
  
  return &$self('AUTOLOADER',$method,@_);
}

1;

# ==========================================================================
#
# POD
#
# ==========================================================================
