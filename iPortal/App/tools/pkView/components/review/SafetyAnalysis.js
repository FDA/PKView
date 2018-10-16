define('tools/pkView/components/review/SafetyAnalysis', [
    'knockout',
    'koSelectize',
    'shared/components/dataDialog/viewmodels/dataDialog',
    'shared/components/errorDialog/viewmodels/errorDialog',
    'ocpkmlib/net',
    'durandal/app',
    'plugins/dialog',
    'shared/components/modal/viewmodels/modal'],
    function (ko, koSelectize, dataDialog, errorDialog, net, app, dialog, modal) {

        // This is the mainWindow viewmodel prototype
        var ctor = function () {
            var self = this;

            self.Analyses = ko.observableArray([]);
            self.IssStudyMappings = ko.observableArray([]);
            self.IssTRTPs = ko.observableArray([]);
            self.TRTxxPs = ko.observableArray([]);
            self.AnalysisType = ko.observable("ITT");
            self.displayTRTP = ko.observable(false);
            self.displaySpinner = ko.observable(false);
            self.safetycomputingReport = ko.observable(false);
            self.ISSfound = ko.observable(false);
            self.AnalysisComplete = ko.observable(false);
            self.CDomains = ko.observableArray([]);
            self.AeCutoffRate = ko.observable("0");
            self.randomNumber = ko.observable("0");
            self.ValuesFound = ko.observable(false);
            self.activeAnalysis = ko.observable("New Analysis");
            self.tempCountValues = ko.observableArray([]);
            self.CumulativeAePooled = ko.observable(true);
            self.CumulativeAeIndividual = ko.observable(true);
            self.DoseResponse = ko.observable(true);
            self.DosingRecord = ko.observable(true);
            self.PkSafetyDdi = ko.observable(true);
            self.ClinicalDose = ko.observable("");
            self.MaxDayCumulative = ko.observable("");
            self.displayML = ko.observable(false);
            self.AesevValues = ko.observableArray([]);
            self.AsevValues = ko.observableArray([]);

            var temp_issMappings = [];
            var TRTParray = [];
            var fileLocations = ["", ""];
            var selVar = "";
            var domainVarsAE = {};
            var domainVarsSL = {};
            var ShowOptions = false;
            var callingFunction = "";
            var SevVariable = "";
            var TempAdaeDimensions = [];
            var DimensionChanged = false;

            self.editSeverity = {
                ADAE: { AESEV: 1, ASEV: 1 }
            };

            // Domain descriptions
            self.IssDomainDescriptions =
            {
                ADAE: "Adverse Events",
                ADSL: "Subject Level",
                ADVS: "Vital Sign"
            };

            // Domain descriptions
            self.DomainCountsDescriptions =
            {
                ADAE: "Adverse Events Count",
                ADSL: "Total Subjects Count"
            };

            //variable descriptions
            self.issVariables =
            {
                ASTDY: {
                    description: "Analysis Start Day",
                    longDescription: "Analysis Start Relative Day: The number of days from an anchor date to the analysis start date.",
                    importance: 0
                },
                ASTDT: {
                    description: "Analysis Start Date",
                    longDescription: "The start date associated with analysis value (AVAL).",
                    importance: 0
                },
                AESTDY: {
                    description: "Analysis E Start Day",
                    longDescription: "Study day of start of adverse event relative to the sponsor-defined reference date.",
                    importance: 0
                },
                AESEV: {
                    description: "Severity / Intensity",
                    longDescription: "The severity or intensity of the event.",
                    importance: 0
                },
                ASEV: {
                    description: "Severity / Intensity",
                    longDescription: "The severity or intensity of the event.",
                    importance: 0
                },
                TRTA: {
                    description: "Treatment",
                    longDescription: "TRTA is a record-level identifier that represents the actual treatment attributed" +
                        " to a record for analysis purposes.",
                    importance: 1
                },
                USUBJID: {
                    description: "Subject Id",
                    longDescription: "Unique Subject Id: Identifier used to uniquely identify a " +
                    "subject across all studies for all applications or " +
                    "submissions involving the product.",
                    importance: 0
                },
                STUDYID: {
                    description: "Study Identifier",
                    longDescription: "Unique identifier for a study within the submission.",
                    importance: 1
                },
                AESER: {
                    description: "Serious Event",
                    longDescription: "Defines if this is a serious event.",
                    importance: 1
                },
                AEBODSYS: {
                    description: "Body system or organ class",
                    longDescription: "Dictionary derived. Body system or organ class used by the sponsor from the coding dictionary.",
                    importance: 1
                },
                AEDECOD: {
                    description: "Dictionary Derived Term",
                    longDescription: "Dictionary-derived text description of adverse event.",
                    importance: 1
                },
                ARM: {
                    description: "Treatment",
                    longDescription: "Planned Arm: Name of the Arm to which the subject was assigned.",
                    importance: 1
                },
                ADY: {
                    description: "Analysis Relative Day",
                    longDescription: "Analysis Relative Day: The number of days from an anchor date to analysis date.",
                    importance: 1
                },
                TRTSDT: {
                    description: "Treatment Start Date",
                    longDescription: "Date of first exposure to treatment for a subject in a study." +
                        " TRTSDT are required if there is an investigational product.",
                    importance: 1
                },
                LSTVSTDT: {
                    description: "Last Visit Date",
                    longDescription: "no description yet",
                    importance: 1
                },
                APERIOD: {
                    description: "adverse period",
                    longDescription: "no description yet",
                    importance: 1
                },
                TRTxxP: {
                    description: "TRTxxP",
                    longDescription: "no description yet",
                    importance: 1
                }
            };

            //function to fetch treatment, order and study id from SAS
            self.showOptions = function () {
                while (TRTParray.length > 0) {
                    TRTParray.pop();
                }

                self.CDomains.removeAll();
                self.IssTRTPs.removeAll();
                self.displaySpinner(true);
                self.getTRTP().done(function (response) {
                    switch (response.Status) {
                        case 0:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;

                        case 1:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 2:
                            ShowOptions = true;
                            self.processTRTP(response.Data);
                            return;
                        case 3:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                    }
                });
            };

            self.editSeverityMapping = function (domain, SelectedVariable, SeverityVariable) {
                SevVariable = SeverityVariable;
                self.callForValue(domain, SelectedVariable, "", "").done(function (response) {
                    switch (response.Status) {
                        case 0:
                            app.showMessage("Values not found", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 1: app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 2:
                            self.processSeverityValues(response);
                            return;
                        case 3:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                    }
                });
            };

            self.processSeverityValues = function (response) {
                var CountValuesTemp = response.Data;
                if (CountValuesTemp == null) {
                    app.showMessage("values not found", 'PkView', ['OK']);
                    self.displaySpinner(false);
                }
                else {
                    self.ValuesFound(true);
                    var FileLocation = "";
                    var tempsev = [];
                    var tempSeverity = [];

                    if (SevVariable == "AESEV") {
                        tempsev = self.AesevValues();
                    }
                    else
                        tempsev = self.AsevValues();

                    if (tempsev.length == 0) {
                        var rec1 = CountValuesTemp.CDomains[0];
                        var rec2 = rec1.Inclusions[0];

                        $.each(rec2.CountValues, function (m, CountValue) {
                            var item = {
                                UniqueValue: CountValue.UniqueValue,
                                order: ""
                            };
                            tempSeverity.push(item);
                        })
                    }
                    else
                        tempSeverity = tempsev;

                    var OrderSeverity = new modal({
                        title: 'Edit Order for ' + selVar.selectedVariable,
                        model: 'tools/pkview/components/review/sections/OrderSeverity',
                        activationData: {
                            SeverityValues: tempSeverity
                        },
                        width: 0.6,
                    });
                    dialog.show(OrderSeverity).done(function (result) {
                        if (result) {
                            if (result.SeverityValues) {
                                var tempSeverity1 = result.SeverityValues;
                                if (SevVariable == "AESEV") {
                                    self.AesevValues([]);
                                }
                                else
                                    self.AsevValues([]);


                                $.each(tempSeverity1, function (m, CountValue) {
                                    var item = {
                                        UniqueValue: CountValue.UniqueValue,
                                        order: CountValue.order
                                    };
                                    if (SevVariable == "AESEV") {
                                        self.AesevValues.push(item);
                                    }
                                    else
                                        self.AsevValues.push(item);
                                })
                            }
                        }
                    });
                }
            };


            self.processTRTP = function (response) {
                var IssTrtp_temp = response;
                var tempTRTarray = [];
                if (IssTrtp_temp == null) {
                    app.showMessage("Treatment values not found", 'PkView', ['OK']);
                    self.displaySpinner(false);
                }
                else {
                    var i = 1;
                    $.each(IssTrtp_temp.IssTRTPs, function (m, IssTRTP) {
                        if (ShowOptions == true)
                            IssTRTP.order = i;
                        var trtTemp = IssTRTP.TRTP;
                        if (tempTRTarray.indexOf(trtTemp) == -1) {
                            var temp_trtp = {
                                StudyId: IssTRTP.StudyId,
                                NumberOfSubjects: IssTRTP.NumberOfSubjects,
                                TRTP: IssTRTP.TRTP,
                                order: ko.observable(IssTRTP.order),
                                IncludeStudy: ko.observable(IssTRTP.IncludeStudy),
                                RevisedTRTP: IssTRTP.RevisedTRTP,
                                ARM: IssTRTP.ARM,
                                StudyDuration: IssTRTP.StudyDuration,
                                sortKey: IssTRTP.sortKey,
                                NumericDose: IssTRTP.NumericDose
                            }
                            tempTRTarray.push(trtTemp);
                            self.IssTRTPs.push(temp_trtp);
                            TRTParray.push(temp_trtp);
                            i++;
                        }
                        else {
                            var temp_trtp = {
                                StudyId: IssTRTP.StudyId,
                                NumberOfSubjects: IssTRTP.NumberOfSubjects,
                                TRTP: "",
                                order: ko.observable(""),
                                IncludeStudy: ko.observable(IssTRTP.IncludeStudy),
                                RevisedTRTP: IssTRTP.RevisedTRTP,
                                ARM: IssTRTP.ARM,
                                StudyDuration: IssTRTP.StudyDuration,
                                sortKey: IssTRTP.sortKey,
                                NumericDose: IssTRTP.NumericDose
                            }
                            self.IssTRTPs.push(temp_trtp);
                        }
                    })
                    self.MaxDayCumulative(IssTrtp_temp.MaxDayCumulative);
                    if (ShowOptions == true)
                        self.showCounts();
                }
            };

            self.showCounts = function () {
                self.displaySpinner(true);
                self.getCount().done(function (response) {
                    switch (response.Status) {
                        case 0:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 1:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 2:
                            self.processCount(response.Data);
                            return;
                        case 3:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                    }
                });
            };

            self.getTRTP = function () {
                return (net.ajax({
                    url: "api/pkview/submissions/IssMappings/getOptions",
                    data: ko.toJSON(temp_issMappings),
                    type: "POST",
                    errorCallback: function () {
                        app.showMessage('An error occured', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                }));
            };

            self.getCount = function () {
                return (net.ajax({
                    url: "api/pkview/submissions/" + self.SubmissionId + "/supplement/" + self.supplementNumber + "/getCounts",
                    errorCallback: function () {
                        app.showMessage('An error occured', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                }));
            };

            self.processCount = function (response) {
                domainVarsAE = {};
                domainVarsSL = {};
                var Count_temp = response;

                var RelationsNum = [{ relation: "=" }, { relation: ">" }, { relation: ">=" }, { relation: "<" }, { relation: "<=" }];
                var RelationsChar = [{ relation: "=" }];

                if (Count_temp == null) {
                    app.showMessage("Count values not found", 'PkView', ['OK']);
                    self.displaySpinner(false);
                }
                else {
                    $.each(Count_temp.CDomains, function (m, CDomain) {
                        var tempCountVariable = [];
                        var InTempSelectedVar = [];
                        var ExTempSelectedVar = [];
                        $.each(CDomain.CVariables, function (m, CVariable) {
                            var item = {
                                CVariableName: CVariable.CVariableName
                            };
                            tempCountVariable.push(item);
                        })
                        $.each(CDomain.Inclusions, function (m, selectedVar) {
                            var Relations = [];
                            if (selectedVar.ValueType == "C")
                                Relations = RelationsChar;
                            if (selectedVar.ValueType == "N")
                                Relations = RelationsNum;

                            var item = {
                                selectedVariable: ko.observable(selectedVar.selectedVariable),
                                selVarDomain: CDomain.CDomainName,
                                InEx: selectedVar.InEx,
                                relation: ko.observable(selectedVar.relation),
                                CountValues: ko.observableArray(selectedVar.CountValues),
                                ValueType: selectedVar.ValueType,
                                FileLocation: selectedVar.FileLocation,
                                Relations: ko.observableArray(Relations),
                                display: ko.observable(selectedVar.display)
                            }
                            InTempSelectedVar.push(item);
                        })
                        $.each(CDomain.Exclusions, function (m, selectedVar) {
                            var Relations = [];
                            if (selectedVar.ValueType == "C")
                                Relations = RelationsChar;
                            if (selectedVar.ValueType == "N")
                                Relations = RelationsNum;

                            var item = {
                                selectedVariable: ko.observable(selectedVar.selectedVariable),
                                selVarDomain: CDomain.CDomainName,
                                InEx: selectedVar.InEx,
                                relation: ko.observable(selectedVar.relation),
                                CountValues: ko.observableArray(selectedVar.CountValues),
                                ValueType: selectedVar.ValueType,
                                FileLocation: selectedVar.FileLocation,
                                Relations: ko.observableArray(Relations),
                                display: ko.observable(selectedVar.display)
                            }

                            ExTempSelectedVar.push(item);
                        })
                        var item = {
                            CDomainName: CDomain.CDomainName,
                            CVariables: tempCountVariable,
                            Inclusions: InTempSelectedVar,
                            Exclusions: ExTempSelectedVar
                        };
                        self.CDomains.push(item);
                    })
                    self.displaySpinner(false);
                    self.displayTRTP(true);
                }
            };

            // Select the supplement(s) we want to work on
            self.selectSupplement = function (supplementNumber) {
                self.displaySpinner(true);
                self.SelectedSupplement(supplementNumber);
                self.supplementNumber = supplementNumber;
                self.IssTRTPs.removeAll();
                self.IssStudyMappings.removeAll();
                self.TRTxxPs.removeAll();
                self.CDomains.removeAll();
                self.displayTRTP(false);
                self.AeCutoffRate("0");
                self.AnalysisType("ITT");
                self.AnalysisComplete(false);
                self.Analyses.removeAll();
                self.CumulativeAePooled(true);
                self.CumulativeAeIndividual(true);
                self.DoseResponse(true);
                self.DosingRecord(true);
                self.PkSafetyDdi(true);
                self.MaxDayCumulative("");
                self.ClinicalDose("");
                self.AesevValues.removeAll();
                self.AsevValues.removeAll();

                while (TRTParray.length > 0) {
                    TRTParray.pop();
                }
                self.fetchAnalyses();
            };

            //send a request to SAS and fetch the ISS mappings
            self.getIssMapping = function () {
                self.displaySpinner(true);
                self.ISSfound(false);
                self.getTemp().done(function (response) {
                    switch (response.Status) {
                        case 0:
                            app.showMessage("ISS data not found", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 1:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                        case 2:
                            self.ISSfound(true);
                            var newStudy = response.Data;
                            net.ajax({
                                url: "/api/pkview/createNewAnalysis",
                                type: "POST",
                                data: ko.toJSON(newStudy),
                                successCallback: function (newAnalysis) {
                                    var item = {
                                        AnalysisName: ko.observable(newAnalysis.AnalysisName),
                                        AnalysisCreationDate: ko.observable(newAnalysis.AnalysisCreationDate),
                                        IssStudy: newAnalysis.IssStudy,
                                        isActive: ko.observable(true),
                                        AnalysisSaved: ko.observable(false)
                                    }
                                    self.Analyses.push(item);
                                    self.activeAnalysis(newAnalysis.AnalysisName);
                                    ko.utils.arrayForEach(self.Analyses(), function (Analysis) {
                                        if (Analysis.AnalysisName() != self.activeAnalysis())
                                            Analysis.isActive(false);
                                    });
                                    self.processMappings(newAnalysis);
                                },
                                errorCallback: function () {
                                    app.showMessage('An error occurred when creating Safety analysis xml file', 'PkView', ['OK']);
                                    self.displaySpinner(false);
                                }
                            });
                            return;
                        case 3:
                            app.showMessage("SAS error", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return;
                    }
                });
            };

            self.getCountValue = function (item) {
                item.Relations.removeAll();
                item.CountValues.removeAll();
                if (item.selectedVariable() == "") {
                    item.display(false);
                }
                else {
                    self.callForValue(item.selVarDomain, item.selectedVariable, item.InEx, "").done(function (response) {
                        switch (response.Status) {
                            case 0:
                                app.showMessage("Values not found", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return;
                            case 1: app.showMessage("SAS error", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return;
                            case 2:
                                self.processValues(response);
                                return;
                            case 3:
                                app.showMessage("SAS error", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return;
                        }
                    });
                }
            };

            self.processValues = function (response) {
                self.ValuesFound(false);
                var tempCountValues = [];
                var tempselectedVar = [];
                var tempCVariables = [];

                var RelationsNum = [{ relation: "=" }, { relation: ">" }, { relation: ">=" }, { relation: "<" }, { relation: "<=" }];
                var RelationsChar = [{ relation: "=" }];

                var CountValuesTemp = response.Data;
                if (CountValuesTemp == null) {
                    app.showMessage("values not found", 'PkView', ['OK']);
                    self.displaySpinner(false);
                }
                else {
                    self.ValuesFound(true);
                    var FileLocation = "";

                    var rec1 = CountValuesTemp.CDomains[0];
                    var rec2 = rec1.Inclusions[0];

                    $.each(rec2.CountValues, function (m, CountValue) {
                        var item = {
                            UniqueValue: CountValue.UniqueValue,
                            SelectValue: false
                        };
                        self.tempCountValues.push(item);
                    })

                    ko.utils.arrayForEach(self.CDomains(), function (CDomain) {
                        if (selVar.InEx == "IN") {
                            ko.utils.arrayForEach(CDomain.Inclusions, function (selectedVar) {
                                if (CDomain.CDomainName == selVar.selVarDomain) {
                                    if (selectedVar.selectedVariable == selVar.selectedVariable) {
                                        selectedVar.CountValues(rec2.CountValues);
                                        if (rec2.ValueType == "C")
                                            selectedVar.Relations(RelationsChar);
                                        else
                                            selectedVar.Relations(RelationsNum);
                                        selectedVar.display(true);
                                        selectedVar.ValueType = rec2.ValueType;
                                    }
                                    if (CDomain.CDomainName == "ADAE") {
                                        FileLocation = fileLocations[0];
                                    }
                                    else {
                                        FileLocation = fileLocations[1];
                                    }
                                    selectedVar.FileLocation = FileLocation;
                                }
                            });
                        }
                        else {
                            ko.utils.arrayForEach(CDomain.Exclusions, function (selectedVar) {
                                if (CDomain.CDomainName == selVar.selVarDomain) {
                                    if (selectedVar.selectedVariable == selVar.selectedVariable) {
                                        selectedVar.CountValues(rec2.CountValues);
                                        if (rec2.ValueType == "C")
                                            selectedVar.Relations(RelationsChar);
                                        else
                                            selectedVar.Relations(RelationsNum);
                                        selectedVar.display(true);
                                        selectedVar.ValueType = rec2.ValueType;
                                    }
                                    if (CDomain.CDomainName == "ADAE") {
                                        FileLocation = fileLocations[0];
                                    }
                                    else {
                                        FileLocation = fileLocations[1];
                                    }
                                    selectedVar.FileLocation = FileLocation;
                                }
                            });
                        }
                    });
                }
            };

            self.callForValue = function (CDomainName, selectedVariable, InEx, Number) {
                var FileLocation = "";
                selVar = "";
                if (CDomainName == "ADAE")
                    FileLocation = fileLocations[0];
                else
                    FileLocation = fileLocations[1];

                selVar = {
                    selectedVariable: selectedVariable,
                    selVarDomain: CDomainName,
                    FileLocation: FileLocation,
                    InEx: InEx,
                    Number: Number
                };

                return (net.ajax({
                    url: "api/pkview/submissions/Domain/getValues",
                    type: "POST",
                    data: ko.toJSON(selVar),
                    errorCallback: function () {
                        app.showMessage('An error occured', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                }));
            };

            self.processMappings = function (Analysis) {
                self.IssStudyMappings.removeAll();
                self.TRTxxPs.removeAll();
                self.CDomains.removeAll();
                self.IssTRTPs.removeAll();
                self.AesevValues.removeAll();
                self.AsevValues.removeAll();
                TempAdaeDimensions = [];
                self.displayTRTP(false);
                self.AeCutoffRate("0");
                self.AnalysisType("ITT");
                self.AnalysisComplete(false);
                self.CumulativeAePooled(true);
                self.CumulativeAeIndividual(true);
                self.DoseResponse(true);
                self.DosingRecord(true);
                self.PkSafetyDdi(true);
                self.MaxDayCumulative("");
                self.ClinicalDose("");

                var IssStudy = Analysis.IssStudy;
                var MLStudy = Analysis.MLStudy;

                //display error message if no study or data found
                if (IssStudy == null) {
                    app.showMessage("ISS data not found", 'PkView', ['OK']);
                    self.ISSfound(false);
                    self.displaySpinner(false);
                }
                else {
                    if (IssStudy.displayOptions == true) {
                        self.AeCutoffRate(IssStudy.AeCutoffRate);
                        self.AnalysisType(IssStudy.AnalysisType);
                        self.processTRTP(IssStudy);
                        self.processCount(IssStudy);
                        self.displayTRTP(true);
                        self.AnalysisComplete(IssStudy.AnalysisComplete);
                        self.CumulativeAePooled(IssStudy.CumulativeAePooled);
                        self.CumulativeAeIndividual(IssStudy.CumulativeAeIndividual);
                        self.DoseResponse(IssStudy.DoseResponse);
                        self.DosingRecord(IssStudy.DosingRecord);
                        self.PkSafetyDdi(IssStudy.PkSafetyDdi);
                        self.ClinicalDose(IssStudy.ClinicalDose);
                        self.MaxDayCumulative(IssStudy.MaxDayCumulative);
                    }

                    $.each(IssStudy.TRTxxPs, function (x, TRTxxP) {
                        var item = {
                            Selection: TRTxxP.Selection,
                            TRTXXP: TRTxxP.TRTXXP,
                        }
                        self.TRTxxPs.push(item);
                    })

                    if (IssStudy.AesevValues != null) {
                        $.each(IssStudy.AesevValues, function (x, AesevValue) {
                            var item = {
                                UniqueValue: AesevValue.UniqueValue,
                                order: AesevValue.order,
                            }
                            self.AesevValues.push(item);
                        })
                    }

                    if (IssStudy.AsevValues != null) {
                        $.each(IssStudy.AsevValues, function (x, AsevValue) {
                            var item = {
                                UniqueValue: AsevValue.UniqueValue,
                                order: AsevValue.order,
                            }
                            self.AsevValues.push(item);
                        })
                    }

                    $.each(IssStudy.IssStudyMappings, function (j, IssDomain) {
                        var tempArray = [];
                        // Make mapping qualities observable, compute optionality and gather a list of unmapped variables                
                        $.each(IssDomain.IssDomainMappings, function (k, IssMapping) {
                            var item = {
                                IssVariable: IssMapping.IssVariable,
                                IssFileVariable: IssMapping.IssFileVariable,
                                IssMappingQuality: IssMapping.IssMappingQuality
                            };
                            tempArray.push(item);
                            IssMapping.IssMappingQuality = ko.observable(IssMapping.IssMappingQuality);
                        })
                        var UIFileVariables = [{ Text: "", Value: "" }].concat(IssDomain.IssFileVariables);
                        var item_temp = {
                            IssDomainType: IssDomain.IssDomainType,
                            IssDomainMappings: tempArray,
                            IssUIFileVariables: UIFileVariables,
                            IssFileVariables: IssDomain.IssFileVariables,
                            IssFileId: IssDomain.IssFileId
                        };
                        if (IssDomain.IssDomainType == "ADAE") {
                            fileLocations[0] = IssDomain.IssFileId;
                        }
                        if (IssDomain.IssDomainType == "ADSL") {
                            fileLocations[1] = IssDomain.IssFileId;
                        }
                        self.IssStudyMappings.push(item_temp);
                        temp_issMappings.push(item_temp);
                    })

                    self.ISSfound(true);
                    self.displaySpinner(false);
                }
            };

            self.getTemp = function () {
                return (net.ajax({
                    url: "api/pkview/submissions/IssMapping",
                    type: "GET",
                    data: { ProfileName: self.ProfileName(), NDAName: self.NDAName(), SupplementNumber: self.supplementNumber },
                    errorCallback: function () {
                        app.showMessage('An error occured', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                }));
            };

            self.ClearAll = function () {
                ko.utils.arrayForEach(self.IssTRTPs(), function (IssTRTP) {
                    IssTRTP.IncludeStudy(false);
                });
            };

            self.ResetOrder = function () {
                ko.utils.arrayForEach(self.IssTRTPs(), function (IssTRTP) {
                    if (IssTRTP.TRTP != "")
                        IssTRTP.order(0);
                });
            };

            self.SelectAll = function () {
                ko.utils.arrayForEach(self.IssTRTPs(), function (IssTRTP) {
                    IssTRTP.IncludeStudy(true);
                });
            };

            self.CopySasCode = function () {
                self.displaySpinner(true);
                var newStudy = {
                    IssNDAName: self.SubmissionId,
                    IssSupplementNumber: self.supplementNumber,
                    IssProfileName: self.ProfileName,
                };

                var newAnalysis = {
                    IssStudy: newStudy,
                    AnalysisName: self.activeAnalysis()
                };

                net.ajax({
                    url: "api/pkview/IssMappings/CopySasCode",
                    type: "POST",
                    data: ko.toJSON(newAnalysis),
                    errorCallback: function () {
                        app.showMessage('An error occured. SafetySummaryPlot.sas could not be saved', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    },
                    successCallback: function (response) {
                        self.displaySpinner(false);
                    }
                });
            };

            self.saveAnalysis = function () {
                self.displaySpinner(true);
                var newStudy = {
                    IssStudyMappings: self.IssStudyMappings(),
                    IssTRTPs: self.IssTRTPs(),
                    TRTxxPs: self.TRTxxPs(),
                    AesevValues: self.AesevValues(),
                    AsevValues: self.AsevValues(),
                    IssNDAName: self.SubmissionId,
                    IssSupplementNumber: self.supplementNumber,
                    IssProfileName: self.ProfileName,
                    IssStudyCode: "ISS",
                    AnalysisType: self.AnalysisType,
                    AeCutoffRate: self.AeCutoffRate,
                    CDomains: self.CDomains(),
                    displayOptions: self.displayTRTP(),
                    AnalysisComplete: self.AnalysisComplete(),
                    CumulativeAePooled: self.CumulativeAePooled,
                    CumulativeAeIndividual: self.CumulativeAeIndividual,
                    DoseResponse: self.DoseResponse,
                    DosingRecord: self.DosingRecord,
                    PkSafetyDdi: self.PkSafetyDdi,
                    ClinicalDose: self.ClinicalDose,
                    MaxDayCumulative: self.MaxDayCumulative,
                    displayML: self.displayML()
                };

                var MLStudy = [];
                var newAnalysis = {
                    IssStudy: newStudy,
                    MLStudy: MLStudy,
                    AnalysisName: self.activeAnalysis()
                };

                net.ajax({
                    url: "api/pkview/saveAnalysis",
                    type: "POST",
                    data: ko.toJSON(newAnalysis),
                    errorCallback: function () {
                        app.showMessage('An error occured. Analysis could not be saved', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    },
                    successCallback: function (response) {
                        ko.utils.arrayForEach(self.Analyses(), function (Analysis) {
                            if (Analysis.AnalysisName() == self.activeAnalysis()) {
                                Analysis.AnalysisCreationDate(response);
                                Analysis.AnalysisSaved(true);
                            }
                        });
                        if (callingFunction == "run") {
                            app.showMessage('Analysis completed and saved', 'PkView', ['OK']);
                        }
                        else {
                            if (callingFunction == "rename")
                                app.showMessage('Analysis renamed and saved', 'PkView', ['OK']);
                            else
                                app.showMessage('Analysis saved', 'PkView', ['OK']);
                        }
                        self.displaySpinner(false);
                    }
                });
            };

            self.deleteAnalysis = function () {
                self.displaySpinner(true);
                net.ajax({
                    url: "api/pkview/deleteAnalysis",
                    type: "GET",
                    data: { ProfileName: self.ProfileName(), NDAName: self.NDAName(), SupplementNumber: self.supplementNumber, AnalysisName: self.activeAnalysis() },
                    errorCallback: function () {
                        app.showMessage('An error occured. Analysis could not be deleted', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    },
                    successCallback: function (response) {
                        if (response == "yes") {
                            self.Analyses.remove(function (analysis) { return analysis.AnalysisName() == self.activeAnalysis() });
                            var tempAnalysis = self.Analyses();
                            if (tempAnalysis == "") {
                                self.activeAnalysis("New Analysis");
                                self.IssStudyMappings.removeAll();
                                self.TRTxxPs.removeAll();
                                self.CDomains.removeAll();
                                self.IssTRTPs.removeAll();
                                self.AesevValues.removeAll();
                                self.AsevValues.removeAll();
                                self.displayTRTP(false);
                                self.AeCutoffRate("0");
                                self.AnalysisType("ITT");
                                self.ISSfound(false);
                                self.AnalysisComplete(false);
                                self.CumulativeAePooled(true);
                                self.CumulativeAeIndividual(true);
                                self.DoseResponse(true);
                                self.DosingRecord(true);
                                self.PkSafetyDdi(true);
                                self.MaxDayCumulative("");
                                self.ClinicalDose("");
                            }
                            else {
                                self.setActiveAnalysis(tempAnalysis[0]);
                                self.processMappings(tempAnalysis[0]);
                            }
                            app.showMessage('Analysis deleted', 'PkView', ['OK']);
                            self.displaySpinner(false);
                        }
                        else {
                            app.showMessage('An error occured. Analysis could not be deleted', 'PkView', ['OK']);
                            self.displaySpinner(false);
                        }
                    }
                });
            };

            self.ReadAnalysis = function (item) {
                self.ISSfound(false);
                self.displayTRTP(false);
                net.ajax({
                    url: "/api/pkview/ReadXML",
                    type: "GET",
                    data: { analysisName: item.AnalysisName(), submission: self.NDAName(), project: self.ProfileName(), supplement: self.supplementNumber },
                    successCallback: function (response) {
                        self.ISSfound(true);
                        self.processMappings(response.Data);
                    },
                    errorCallback: function () {
                        app.showMessage('An error occurred when reading Safety analysis xml file', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                });
                self.activeAnalysis(item.AnalysisName());
            };

            self.setActiveAnalysis = function (item) {
                self.displaySpinner(true);
                self.activeAnalysis(item.AnalysisName());
                ko.utils.arrayForEach(self.Analyses(), function (Analysis) {
                    if (Analysis.AnalysisName() == self.activeAnalysis())
                        Analysis.isActive(true);
                    else
                        Analysis.isActive(false);
                });
                self.ReadAnalysis(item);
            };

            self.createNewAnalysis = function () {
                self.displayTRTP(false);
                self.getIssMapping();
            };

            self.editAnalysisName = function () {
                callingFunction = "";
                self.displaySpinner(true);
                var editAnalysisName = new modal({
                    title: 'Edit Analysis Name',
                    model: 'tools/pkview/components/review/sections/editAnalysisName',
                    activationData: {
                        AnalysisName: self.activeAnalysis(),
                        ProfileName: self.ProfileName(),
                        NDAName: self.NDAName(),
                        SupplementNumber: self.supplementNumber
                    },
                    width: 0.6,
                });
                dialog.show(editAnalysisName).done(function (result) {
                    if (result) {
                        if (result.renamed == true) {
                            var NewName = result.NewName;
                            if (NewName.indexOf(".xml") == -1)
                                NewName = NewName + ".xml";
                            ko.utils.arrayForEach(self.Analyses(), function (Analysis) {
                                if (Analysis.AnalysisName() == self.activeAnalysis()) {
                                    Analysis.AnalysisName(NewName);
                                    self.activeAnalysis(NewName);
                                }
                            });
                            callingFunction = "rename";
                            self.saveAnalysis();
                        }
                    }
                    self.displaySpinner(false);
                });
            };

            // View domain data
            self.viewData = function (IssDomain) {
                dialog.show(new dataDialog(IssDomain.IssFileId, self.IssDomainDescriptions[IssDomain.IssDomainType] + " File Data"));
            };

            // View domain data
            self.viewData1 = function (CDomain) {
                var FileLocation = "";
                if (CDomain.CDomainName == "ADAE")
                    FileLocation = fileLocations[0];
                else
                    FileLocation = fileLocations[1];
                dialog.show(new dataDialog(FileLocation, self.IssDomainDescriptions[CDomain.CDomainName] + " File Data"));
            };

            // Change quality value of mapping to good when user edits the value
            self.changeQuality = function (item) {
                item.IssMappingQuality = 1;
                if (item.IssVariable == "AESEV")
                    self.AesevValues.removeAll();
                else
                    self.AsevValues.removeAll();
            };

            //function to send data to SAS to run the analysis
            self.runIssAnalysis = function () {
                self.AnalysisComplete(false);
                self.displaySpinner(true);
                var errorFound = 0;
                var value = 0;
                callingFunction = "";

                ko.utils.arrayForEach(self.IssTRTPs(), function (IssTRTP) {
                    if (IssTRTP.IncludeStudy())
                        value++;
                });
                if (value == 0) {
                    errorFound = 1;
                    app.showMessage("Please select study", 'PkView', ['OK']);
                    self.displaySpinner(false);
                    return false;
                }

                errorFound = 0;
                var cutRate = self.AeCutoffRate();
                if (isNaN(cutRate) || cutRate == "") {
                    errorFound = 1;
                    app.showMessage("Cutoff of AE rate should be numeric", 'PkView', ['OK']);
                    self.displaySpinner(false);
                    return false;
                }
                $.each(TRTParray, function (m, IssTRTP) {
                    if (IssTRTP.IncludeStudy() == true) {
                        if (isNaN(IssTRTP.order())) {
                            errorFound = 1;
                            app.showMessage("order value should be numeric", 'PkView', ['OK']);
                            self.displaySpinner(false);
                            return false;
                        }
                    }
                })

                value = 0;
                ko.utils.arrayForEach(self.CDomains(), function (CDomain) {
                    ko.utils.arrayForEach(CDomain.Inclusions, function (selectedVar) {
                        if (selectedVar.display() == true) {
                            if (selectedVar.relation() == undefined) {
                                errorFound = 1;
                                app.showMessage("Please select relation", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return false;
                            }
                            ko.utils.arrayForEach(selectedVar.CountValues(), function (CountValue) {
                                if (CountValue.SelectValue == true)
                                    value++;
                            })
                            if (value == 0) {
                                errorFound = 1;
                                app.showMessage("Please select value", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return false;
                            }
                        }
                    })
                    value = 0;
                    ko.utils.arrayForEach(CDomain.Exclusions, function (selectedVar) {
                        if (selectedVar.display() == true) {
                            if (selectedVar.relation === undefined) {
                                errorFound = 1;
                                app.showMessage("Please select relation", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return false;
                            }
                            ko.utils.arrayForEach(selectedVar.CountValues(), function (CountValue) {
                                if (CountValue.SelectValue == true)
                                    value++;
                            })
                            if (value == 0) {
                                errorFound = 1;
                                app.showMessage("Please select value", 'PkView', ['OK']);
                                self.displaySpinner(false);
                                return false;
                            }
                        }
                    })
                })

                if (errorFound == 0) {
                    self.displaySpinner(true);
                    var randomNum = Math.floor(Math.random() * 100000) + 1;
                    self.randomNumber(randomNum);

                    var newStudy = {
                        IssStudyMappings: self.IssStudyMappings(),
                        IssTRTPs: self.IssTRTPs(),
                        TRTxxPs: self.TRTxxPs(),
                        IssNDAName: self.SubmissionId,
                        IssSupplementNumber: self.supplementNumber,
                        IssProfileName: self.ProfileName,
                        IssStudyCode: "ISS",
                        AnalysisType: self.AnalysisType,
                        RandomNumber: self.randomNumber,
                        AeCutoffRate: self.AeCutoffRate,
                        CDomains: self.CDomains(),
                        CumulativeAePooled: self.CumulativeAePooled,
                        CumulativeAeIndividual: self.CumulativeAeIndividual,
                        DoseResponse: self.DoseResponse,
                        DosingRecord: self.DosingRecord,
                        PkSafetyDdi: self.PkSafetyDdi,
                        ClinicalDose: self.ClinicalDose,
                        MaxDayCumulative: self.MaxDayCumulative,
                        AesevValues: self.AesevValues(),
                        AsevValues: self.AsevValues()
                    };
                    var newAnalysis = {
                        IssStudy: newStudy,
                        AnalysisName: self.activeAnalysis()
                    };

                    net.ajax({
                        cache: false,
                        url: "api/pkview/submissions/IssMappings/runAnalysis",
                        data: ko.toJSON(newAnalysis),
                        type: "POST",
                        successCallback: function (jobId) {
                            self.displayProgress(jobId, self.splash);
                        },
                        errorCallback: function () {
                            app.showMessage('Analysis failed', 'PkView', ['OK']);
                            self.displaySpinner(false);
                        }
                    });
                }
            };

            self.displayProgress = function (jobId, splash) {
                var displayProgress = new modal({
                    title: 'Display progress',
                    model: 'tools/pkview/components/review/sections/displayProgress',
                    activationData: {
                        jobId: jobId,
                        splash: splash
                    },
                    width: 0.4,
                });
                dialog.show(displayProgress).done(function (result) {
                    if (result) {
                        if (result.complete == true) {
                            self.AnalysisComplete(true);
                            callingFunction = "run";
                            self.CopySasCode();
                            self.saveAnalysis();
                            self.displaySpinner(false);
                        }
                        else
                            app.showMessage("SAS error", 'PkView', ['OK']);
                    }
                    self.displaySpinner(false);
                });
            };

            // Generate and download Safety Analysis package
            self.getSafetyPackage = function () {
                self.displaySpinner(true);
                // Do nothing if download function is already in progress
                if (self.safetycomputingReport()) return false;
                self.safetycomputingReport(true);
                // Create and download results package
                self.docreateSafetyPackage();
                self.displaySpinner(false);
            };

            self.docreateSafetyPackage = function () {
                net.ajax({
                    url: "/api/pkview/DownloadSafetyReport",
                    data: { submission: self.NDAName, project: self.ProfileName, supplement: self.supplementNumber, AnalysisName: self.activeAnalysis() },
                    successCallback: function (result) {
                        if (result == "yes") {
                            self.safetycomputingReport(false);
                            self.downloadSafetyPackage(self.NDAName(), self.ProfileName(), self.supplementNumber);
                            self.displaySpinner(false);
                        }
                        else {
                            self.safetycomputingReport(false);
                            app.showMessage(result, 'PkView', ['OK']);
                            self.displaySpinner(false);
                        }
                    },
                    errorCallback: function () {
                        app.showMessage('An error occurred when creating Safety analysis report package', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    }
                });
            };

            self.downloadSafetyPackage = function (NDAName, ProfileName, activeSupplement) {
                var ThisAnalysis = self.activeAnalysis();
                var AnalysisFolder = ThisAnalysis.split(".xml");
                if (ProfileName == null) ProfileName = "";
                net.download("/api/download/PkView/" + "Safety Analysis" + ".zip?subfolder=" + ProfileName + "/" + NDAName + "/" + activeSupplement + "/ISS/" + AnalysisFolder[0] + "/");
            };

            // Split variables in two columns
            self.splitInTwoColumns = function (temp_Variables) {
                var result = [];
                for (var i = 0; i < temp_Variables.length; i++) {
                    if (i % 2 == 0)
                        result.push([temp_Variables[i]]);
                    else
                        result[result.length - 1].push(temp_Variables[i]);
                }
                return result;
            };

            // Split variables in four columns
            self.splitInFourColumns = function (temp_Variables) {
                var result = [];
                for (var i = 0; i < temp_Variables.length; i++) {
                    if (i % 4 == 0)
                        result.push([temp_Variables[i]]);
                    else
                        result[result.length - 1].push(temp_Variables[i]);
                }
                return result;
            };

            self.deleteIfNotSaved = function () {
                ko.utils.arrayForEach(self.Analyses(), function (Analysis) {
                    if (!Analysis.AnalysisSaved()) {
                        self.activeAnalysis(Analysis.AnalysisName);
                        self.deleteAnalysis();
                    }
                });
            };

            self.fetchAnalyses = function () {
                self.displaySpinner(true);
                self.ISSfound(false);
                return (net.ajax({
                    url: "api/pkview/fetchAnalyses",
                    type: "GET",
                    data: { ProfileName: self.ProfileName(), NDAName: self.NDAName(), SupplementNumber: self.supplementNumber },
                    errorCallback: function () {
                        app.showMessage('An error occured', 'PkView', ['OK']);
                        self.displaySpinner(false);
                    },
                    successCallback: function (response) {
                        var tempAnalyses = response;

                        $.each(tempAnalyses, function (m, Analysis) {
                            if (m == 0) {
                                var item = {
                                    AnalysisName: ko.observable(Analysis.AnalysisName),
                                    AnalysisCreationDate: ko.observable(Analysis.AnalysisCreationDate),
                                    IssStudy: Analysis.IssStudy,
                                    MLStudy: Analysis.MLStudy,
                                    isActive: ko.observable(true),
                                    AnalysisSaved: ko.observable(true)
                                }
                            }
                            else {
                                var item = {
                                    AnalysisName: ko.observable(Analysis.AnalysisName),
                                    AnalysisCreationDate: ko.observable(Analysis.AnalysisCreationDate),
                                    IssStudy: Analysis.IssStudy,
                                    MLStudy: Analysis.MLStudy,
                                    isActive: ko.observable(false),
                                    AnalysisSaved: ko.observable(true)
                                }
                            }

                            self.Analyses.push(item);
                            if (m == 0) {
                                self.activeAnalysis(Analysis.AnalysisName);
                                self.processMappings(Analysis);
                            }
                        })
                        self.displaySpinner(false);
                    }
                }));
            };
        }

        // After view is activated
        ctor.prototype.activate = function (settings) {
            var self = this;
            self.SubmissionId = settings.data.name();
            self.NDAName = settings.data.name;
            self.ProfileName = settings.data.profile;
            self.error = settings.error;
            self.allowedSteps = settings.allowedSteps;
            self.supplementNumber = "";
            self.SelectedSupplement = ko.observable("");
            self.supplements = ko.observableArray([]);
            self.splash = settings.splash;
            self.splash.visible(false);
            self.displaySpinner(true);

            self.getListOfSerialNumbers = function () {
                return net.ajax({ url: "api/pkview/submissions/" + self.SubmissionId + "/SerialNumbers" });
            };

            self.getListOfSerialNumbers().done(function (supplements) {
                $.each(supplements, function (i, supplement) {
                    self.supplements.push(supplements[i]);
                });
                self.supplementNumber = supplements[0];
                self.SelectedSupplement(supplements[0]);

                self.fetchAnalyses();
            });

            settings.ready();
        };

        // After view is attached
        ctor.prototype.attached = function (view) {
            var self = this;
        };

        // Before view is detached, clean up
        ctor.prototype.detached = function () {
            var self = this;
            self.deleteIfNotSaved();
        };

        ctor.prototype.close = function () {
            var self = this;
            self.close();
        };

        return ctor;
    });
