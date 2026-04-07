#ifndef INC_WX_STUFF_H
#define INC_WX_STUFF_H

#include <wx/sizer.h>
#include <wx/textctrl.h>
#include <wx/button.h>
#include <wx/dialog.h>
#include <wx/app.h>

class HeadersDialog: public wxDialog {
	public:
		void setFilename(wxString fname);
		HeadersDialog(wxWindow* parent,wxWindowID id = -1);
		virtual ~HeadersDialog();

	private:
		void btnBrowseClick(wxCommandEvent& event);
		void btnAddHeadClick(wxCommandEvent& event);
		void btnRemHeadClick(wxCommandEvent& event);
		void txtFilenameChanged(wxCommandEvent& event);

		static const long TXT_FILENAME;
		static const long BTN_BROWSE;
		static const long BTN_ADDHEAD;
		static const long BTN_REMHEAD;

		wxButton *btnBrowse;
		wxButton *btnAddHead;
		wxButton *btnRemHead;
		wxTextCtrl *txtFilename;

		DECLARE_EVENT_TABLE()
};

class HeadersApp : public wxApp {
	public:
		virtual bool OnInit();
};

#endif /* INC_WX_STUFF_H */

