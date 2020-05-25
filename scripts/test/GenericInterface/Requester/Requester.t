# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $RandomID = $Kernel::OM->Get('Kernel::System::UnitTest::Helper')->GetRandomID();

my @Tests = (
    {
        Name             => 'Simple HTTP request',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Requester => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Invoker => {
                    test_operation => {
                        Type           => 'Test::TestSimple',
                        MappingInbound => {
                            Type   => 'Test',
                            Config => {
                                TestOption => 'ToUpper',
                            },
                        },
                        MappingOutbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        InputData => {
            TicketID => 123,
        },
        ReturnData => {
            TICKETID => 123,
        },
        ResponseSuccess => 1,
    },
    {
        Name             => 'Simple HTTP request with umlaut',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Requester => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Invoker => {
                    test_operation => {
                        Type           => 'Test::TestSimple',
                        MappingInbound => {
                            Type   => 'Test',
                            Config => {
                                TestOption => 'ToUpper',
                            },
                        },
                        MappingOutbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        InputData => {
            TicketID => 123,
            b        => 'ö',
        },
        ReturnData => {
            TICKETID => 123,
            B        => 'Ö',
        },
        ResponseSuccess => 1,
    },
    {
        Name             => 'Simple HTTP request with Unicode',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Requester => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Invoker => {
                    test_operation => {
                        Type => 'Test::TestSimple',
                    },
                },
            },
        },
        InputData => {
            TicketID => 123,
            b        => '使用下列语言',
            c        => 'Языковые',
        },
        ReturnData => {
            TicketID => 123,
            b        => '使用下列语言',
            c        => 'Языковые',
        },
        ResponseSuccess => 1,
    },
    {
        Name             => 'Failing HTTP request',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Requester => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 1,
                    },
                },
                Invoker => {
                    test_operation => {
                        Type           => 'Test::TestSimple',
                        MappingInbound => {
                            Type   => 'Test',
                            Config => {
                                TestOption => 'ToUpper',
                            },
                        },
                        MappingOutbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        InputData => {
            TicketID => 123,
        },
        ReturnData      => {},
        ResponseSuccess => 0,
    },
);

# get objects
my $WebserviceObject = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');
my $RequesterObject  = $Kernel::OM->Get('Kernel::GenericInterface::Requester');

for my $Test (@Tests) {

    # add config
    my $WebserviceID = $WebserviceObject->WebserviceAdd(
        Config  => $Test->{WebserviceConfig},
        Name    => "$Test->{Name} $RandomID",
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $WebserviceID,
        "$Test->{Name} WebserviceAdd()",
    );

    #
    # Run actual test
    #
    my $FunctionResult = $RequesterObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => 'test_operation',
        Data         => $Test->{InputData},
    );

    if ( $Test->{ResponseSuccess} ) {

        $Self->True(
            $FunctionResult->{Success},
            "$Test->{Name} success status",
        );

        my $ResponseData;
        if ( ref $FunctionResult->{Data} eq 'HASH' ) {
            $ResponseData = $FunctionResult->{Data}->{ResponseData};
        }

        for my $Key ( sort keys %{ $Test->{ResponseData} || {} } ) {
            my $QueryStringPart = URI::Escape::uri_escape_utf8($Key);
            if ( $Test->{ResponseData}->{$Key} ) {
                $QueryStringPart
                    .= '=' . URI::Escape::uri_escape_utf8( $Test->{ResponseData}->{$Key} );
            }

            $Self->True(
                index( $ResponseData, $QueryStringPart ) > -1,
                "$Test->{Name} result data contains $QueryStringPart",
            );
        }
    }
    else {
        $Self->False(
            $FunctionResult->{Success},
            "$Test->{Name} error status",
        );
    }

    # delete config
    my $Success = $WebserviceObject->WebserviceDelete(
        ID     => $WebserviceID,
        UserID => 1,
    );

    $Self->True(
        $Success,
        "$Test->{Name} WebserviceDelete()",
    );
}

#
# Test non existing web service
#
my $FunctionResult = $RequesterObject->Run(
    WebserviceID => -1,
    Invoker      => 'test_operation',
    Data         => {
        1 => 1
    },
);

$Self->False(
    $FunctionResult->{Success},
    "Non existing web service error status",
);

# cleanup cache
$Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

1;
