#include <wx/msgdlg.h>
#include <wx/app.h>
#include <cstdio>
#include "wx_stuff.h"

const long HeadersDialog::TXT_FILENAME = wxNewId();
const long HeadersDialog::BTN_BROWSE   = wxNewId();
const long HeadersDialog::BTN_ADDHEAD  = wxNewId();
const long HeadersDialog::BTN_REMHEAD  = wxNewId();

BEGIN_EVENT_TABLE(HeadersDialog,wxDialog)
END_EVENT_TABLE()

HeadersDialog::HeadersDialog(wxWindow* parent, wxWindowID id) {
	wxGridSizer* sizeMain;     // Contains everything
	wxFlexGridSizer* sizeFile; // Contains file section
	wxBoxSizer* sizeAddRem;    // Contains header buttons

	// Create the Main Window
	Create(parent, wxID_ANY, _("The Utility for SNES Headers"), wxDefaultPosition,
		wxDefaultSize, wxDEFAULT_DIALOG_STYLE, _T("wxID_ANY"));

	// Create all our nice things
	txtFilename = new wxTextCtrl(this, TXT_FILENAME, wxEmptyString, wxDefaultPosition,
		wxSize(180,27), wxTE_READONLY, wxDefaultValidator, _T("TXT_FILENAME"));
	btnBrowse = new wxButton(this, BTN_BROWSE, _("Browse"), wxDefaultPosition,
		wxSize(90,27), 0,	wxDefaultValidator, _T("BTN_BROWSE"));
	btnAddHead = new wxButton(this, BTN_ADDHEAD, _("Add Header"),
		wxDefaultPosition, wxSize(135,27), 0, wxDefaultValidator, _T("BTN_ADDHEAD"));
	btnRemHead = new wxButton(this, BTN_REMHEAD, _("Remove Header"),
		wxDefaultPosition, wxSize(135,27), 0, wxDefaultValidator, _T("BTN_REMHEAD"));

	// Buttons should be disabled until a file is loaded
	btnAddHead->Disable();
	btnRemHead->Disable();

	// Create sizeFile, put txtFilename and btnBrowse inside of it
	sizeFile = new wxFlexGridSizer(1, 2, 0, 0);
	sizeFile->Add(txtFilename, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
	sizeFile->Add(btnBrowse, 1,   wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);

	// Create sizeAddRem, put btnAddHead and btnRemHead inside of it
	sizeAddRem = new wxBoxSizer(wxHORIZONTAL);
	sizeAddRem->Add(btnAddHead, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
	sizeAddRem->Add(btnRemHead, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);

	// Create sizeMain, put everything inside of it (sizeFile and sizeAddRem)
	sizeMain = new wxGridSizer(2, 1, 0, 0);
	sizeMain->Add(sizeFile, 1,   wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);
	sizeMain->Add(sizeAddRem, 1, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL, 5);

	SetSizer(sizeMain);
	sizeMain->SetSizeHints(this);

	// Connect event functions
	Connect(BTN_BROWSE,wxEVT_COMMAND_BUTTON_CLICKED,
		(wxObjectEventFunction)&HeadersDialog::btnBrowseClick);
	Connect(BTN_ADDHEAD,wxEVT_COMMAND_BUTTON_CLICKED,
		(wxObjectEventFunction)&HeadersDialog::btnAddHeadClick);
	Connect(BTN_REMHEAD,wxEVT_COMMAND_BUTTON_CLICKED,
		(wxObjectEventFunction)&HeadersDialog::btnRemHeadClick);
	Connect(TXT_FILENAME,wxEVT_COMMAND_TEXT_UPDATED,
		(wxObjectEventFunction)&HeadersDialog::txtFilenameChanged);
}

HeadersDialog::~HeadersDialog() { } // What the hell does this even do?

IMPLEMENT_APP(HeadersApp);
bool HeadersApp::OnInit() {
	HeadersDialog Dlg(0);
	SetTopWindow(&Dlg);
	if (argc > 1)
		Dlg.setFilename(argv[1]);
	Dlg.ShowModal();
	return false;
}

