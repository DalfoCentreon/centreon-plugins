#
# Copyright 2023 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::vmware::connector::mode::statushost;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return 'status ' . $self->{result_values}->{status};
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{status} = $options{new_datas}->{$self->{instance} . '_state'};
    return 0;
}

sub custom_overall_output {
    my ($self, %options) = @_;

    return 'overall status is ' . $self->{result_values}->{overall_status};
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'host', type => 1, cb_prefix_output => 'prefix_host_output', message_multiple => 'All ESX Hosts are ok' }
    ];
    
    $self->{maps_counters}->{host} = [
        {
            label => 'status', type => 2, unknown_default => '%{status} !~ /^connected$/i',
            set => {
                key_values => [ { name => 'state' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        {
            label => 'overall-status', type => 2,
            unknown_default => '%{overall_status} =~ /gray/i',
            warning_default => '%{overall_status} =~ /yellow/i',
            critical_default => '%{overall_status} =~ /red/i',
            set => {
                key_values => [ { name => 'overall_status' } ],
                closure_custom_output => $self->can('custom_overall_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub prefix_host_output {
    my ($self, %options) = @_;

    return "Host '" . $options{instance_value}->{display} . "' : ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => { 
        'esx-hostname:s'     => { name => 'esx_hostname' },
        'filter'             => { name => 'filter' },
        'scope-datacenter:s' => { name => 'scope_datacenter' },
        'scope-cluster:s'    => { name => 'scope_cluster' }
    });
    
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{host} = {};
    my $response = $options{custom}->execute(
        params => $self->{option_results},
        command => 'statushost'
    );

    foreach my $host_id (keys %{$response->{data}}) {
        my $host_name = $response->{data}->{$host_id}->{name};
        $self->{host}->{$host_name} = {
            display => $host_name, 
            state => $response->{data}->{$host_id}->{state},
            overall_status => $response->{data}->{$host_id}->{overall_status}
        };
    }    
}

1;

__END__

=head1 MODE

Check ESX global status.

=over 8

=item B<--esx-hostname>

ESX hostname to check.
If not set, we check all ESX.

=item B<--filter>

ESX hostname is a regexp.

=item B<--scope-datacenter>

Search in following datacenter(s) (can be a regexp).

=item B<--scope-cluster>

Search in following cluster(s) (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (Default: '%{status} !~ /^connected$/i').
You can use the following variables: %{status}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (Default: '').
You can use the following variables: %{status}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (Default: '').
You can use the following variables: %{status}

=item B<--unknown-overall-status>

Define the conditions to match for the status to be WARNING (Default: '%{overall_status} =~ /gray/i').
You can use the following variables: %{overall_status}

=item B<--warning-overall-status>

Define the conditions to match for the status to be WARNING (Default: '%{overall_status} =~ /yellow/i').
You can use the following variables: %{overall_status}

=item B<--critical-overall-status>

Define the conditions to match for the status to be CRITICAL (Default: '%{overall_status} =~ /red/i').
You can use the following variables: %{overall_status}

=back

=cut
