#include <wx/msgdlg.h>
#include <wx/string.h>
#include <wx/filedlg.h>
#include "addrem/addrem.h"
#include "wx_stuff.h"
#include "main.h"

// Converts wxString to char*. I really hate wxStrings
char *wxStr(wxString wx_str) {
	char *str = (char *)(malloc(FILENAME_MAX)); // I only use this function for filenames
	strcpy(str, (const char*)wx_str.mb_str(wxConvUTF8));
	return str;
}

// Print a relevant message for function output
int messages(int msg) {
	switch (msg) {
		// Errors
		case ERROR_OPENREAD:
			msgBox("Unable to open file for reading.", "Error", wxICON_ERROR);
		break;
		case ERROR_FAILDETECT:
			msgBox("Header detection has failed. This file may be corrupt.", "Error", wxICON_ERROR);
		break;
		// Header detection stuff
		case STAT_HEADER:
			msgBox("This file is headered.", "TUSH", wxICON_INFORMATION);
		break;
		case STAT_NOHEADER:
			msgBox("This file is unheadered.", "TUSH", wxICON_INFORMATION);
		break;
		// Generic success message
		default:
			msgBox("Done!", "TUSH", wxICON_INFORMATION);
		break;
	}
	return msg;
}

void HeadersDialog::setFilename(wxString fname) {
	txtFilename->SetValue(fname);
}

void HeadersDialog::btnBrowseClick(wxCommandEvent& event) { // Load a file
	// Create a file open dialog
	wxFileDialog* OpenDialog = new wxFileDialog(
		this, _("Choose a file to open"), wxEmptyString, wxEmptyString,
		_("SNES roms (*.smc;*.sfc;*.swc;*.fig)|*.smc;*.sfc;*.swc;*.fig|All files (*.*)|*.*|"),
		wxFD_OPEN |wxFD_FILE_MUST_EXIST, wxDefaultPosition);

	// And show it
	if (OpenDialog->ShowModal() == wxID_OK) // The user clicked "Open"
		txtFilename->SetValue(OpenDialog->GetPath()); // Store the filename in the textbox
	OpenDialog->Destroy();
}

void HeadersDialog::btnAddHeadClick(wxCommandEvent& event) { // Add header
	char *fname = wxStr(txtFilename->GetValue());
	int error = addHeader(fname);
	if (!error) {
		btnAddHead->Disable();
		btnRemHead->Enable();
	}
	messages(error);
}

void HeadersDialog::btnRemHeadClick(wxCommandEvent& event) { // Remove header
	char *fname = wxStr(txtFilename->GetValue());
	int error = remHeader(fname);
	if (!error) {
		btnAddHead->Enable();
		btnRemHead->Disable();
	}
	messages(error);
}

void HeadersDialog::txtFilenameChanged(wxCommandEvent& event) { // Load file
	/* Detect header and enable appropriate button */
	int error = chkHeader(wxStr(txtFilename->GetValue()));
	switch (error) {
		case STAT_HEADER: { // Headered rom
			btnAddHead->Disable();
			btnRemHead->Enable();
		} break;
		case STAT_NOHEADER: { // Unheadered rom
			btnAddHead->Enable();
			btnRemHead->Disable();
		} break;
		default: { // Error has occured
			btnAddHead->Disable();
			btnRemHead->Disable();
		} break;
	}
	messages(error);
}
