// --
// OTOBO is a web-based ticketing system for service organisations.
// --
// Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
// Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/
// --
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.CustomerUserInformationCenterSearch
 * @memberof Core.Agent
 * @author
 * @description
 *      This namespace contains the special module functions for the customer information center search.
 */
Core.Agent.CustomerUserInformationCenterSearch = (function (TargetNS) {

    /**
     * @private
     * @name ShowWaitingDialog
     * @memberof Core.Agent.CustomerUserInformationCenterSearch
     * @function
     * @description
     *      Shows waiting dialog until screen is ready.
     */
    function ShowWaitingDialog(){
        Core.UI.Dialog.ShowContentDialog('<div class="Spacing Center"><span class="AJAXLoader" title="' + Core.Language.Translate('Loading...') + '"></span></div>', Core.Language.Translate('Loading...'), '10px', 'Center', true);
    }

    /**
     * @private
     * @name Redirect
     * @memberof Core.Agent.CustomerUserInformationCenterSearch
     * @function
     * @param {String} CustomerUserID
     * @param {Object} Event
     * @description
     *      Redirect to Customer User ID screen.
     */
    function Redirect(CustomerUserID, Event) {
        var Session = '';

        Event.preventDefault();
        Event.stopPropagation();
        ShowWaitingDialog();

        // add session data, if needed
        if (!Core.Config.Get('SessionIDCookie')) {
            Session = ';' + Core.Config.Get('SessionName') + '=' + Core.Config.Get('SessionID');
        }

        window.location.href = Core.Config.Get('Baselink') + 'Action=AgentCustomerUserInformationCenter;CustomerUserID=' + encodeURIComponent(CustomerUserID) + Session;
    }

    /**
     * @name InitAutocomplete
     * @memberof Core.Agent.CustomerUserInformationCenterSearch
     * @function
     * @param {jQueryObject} $Input - Input element to add auto complete to.
     * @param {String} Subaction - Subaction to execute, "SearchCustomerID" or "SearchCustomerUser".
     * @description
     *      Initialize autocompletion.
     */
    TargetNS.InitAutocomplete = function ($Input, Subaction) {
        Core.UI.Autocomplete.Init($Input, function (Request, Response) {
                var URL = Core.Config.Get('Baselink'), Data = {
                    Action: 'AgentCustomerUserInformationCenterSearch',
                    Subaction: Subaction,
                    Term: Request.term,
                    MaxResults: Core.UI.Autocomplete.GetConfig('MaxResultsDisplayed')
                };

                $Input.data('AutoCompleteXHR', Core.AJAX.FunctionCall(URL, Data, function (Result) {
                    var ValueData = [];
                    $Input.removeData('AutoCompleteXHR');
                    $.each(Result, function () {
                        ValueData.push({
                            label: this.Label,
                            value: this.Value
                        });
                    });
                    Response(ValueData);
                }));
        }, function (Event, UI) {
            Redirect(UI.item.value, Event);
        }, 'CustomerSearch');
    };

    /**
     * @name OpenSearchDialog
     * @memberof Core.Agent.CustomerUserInformationCenterSearch
     * @function
     * @description
     *      This function open the search dialog after clicking on "search" button in nav bar.
     */
    TargetNS.OpenSearchDialog = function () {

        var Data = {
            Action: 'AgentCustomerUserInformationCenterSearch'
        };

        ShowWaitingDialog();

        Core.AJAX.FunctionCall(
            Core.Config.Get('CGIHandle'),
            Data,
            function (HTML) {
                // if the waiting dialog was cancelled, do not show the search
                //  dialog as well
                if (!$('.Dialog:visible').length) {
                    return;
                }
                Core.UI.Dialog.ShowContentDialog(HTML, Core.Language.Translate('Search'), '10px', 'Center', true);
                TargetNS.Init();

            }, 'html'
        );
    };

    /**
     * @name Init
     * @memberof Core.Agent.CustomerUserInformationCenterSearch
     * @function
     * @description
     *      This function initializes the search dialog.
     */
    TargetNS.Init = function () {
        TargetNS.InitAutocomplete($("#AgentCustomerUserInformationCenterSearchCustomerUser"), 'SearchCustomerUser');

        // Prevent form submit.
        $("#AgentCustomerUserInformationCenterSearchForm").submit(function(Event) {
          Event.preventDefault();
        });
    };

    return TargetNS;
}(Core.Agent.CustomerUserInformationCenterSearch || {}));
