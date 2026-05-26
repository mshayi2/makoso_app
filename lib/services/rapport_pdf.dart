import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates printable PDF reports for MAKOSO Services and MARINA Trans.
/// Uses built-in Helvetica fonts (no network required).
class RapportPdf {
  RapportPdf._();

  static final _numFmt = NumberFormat('#,##0.00', 'fr_FR');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  // ── PDF colours ────────────────────────────────────────────────────────────
  static final _cHeaderBg    = PdfColor.fromHex('1E3A5F');
  static final _cSectionBg   = PdfColor.fromHex('EFF6FF');
  static final _cSectionText = PdfColor.fromHex('1E40AF');
  static final _cRowAlt      = PdfColor.fromHex('F9FAFB');
  static final _cBorder      = PdfColor.fromHex('E5E7EB');
  static final _cBlue        = PdfColor.fromHex('1D4ED8');
  static final _cGreen       = PdfColor.fromHex('16A34A');
  static final _cRed         = PdfColor.fromHex('DC2626');
  static final _cPurple      = PdfColor.fromHex('7C3AED');
  static final _cGrey        = PdfColor.fromHex('6B7280');
  static final _cDark        = PdfColor.fromHex('374151');

  static String _n(num? v) => _numFmt.format(v ?? 0);
  static String _today() => _dateFmt.format(DateTime.now());

  // ── Public builders ────────────────────────────────────────────────────────

  /// Builds the MAKOSO Services monthly report PDF (A4 portrait).
  static Future<Uint8List> buildMakoso({
    required String periodeLabel,
    required List<Map<String, Object?>> financialRows,
    required Map<String?, double> soldeReporte,
    required List<Map<String, Object?>> dossierRows,
    required List<Map<String, Object?>> souffranceRows,
  }) async {
    final font     = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final doc      = pw.Document(title: 'Rapport mensuel MAKOSO Services');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      header: (ctx) => _docHeader(
          'MAKOSO Services', periodeLabel, font, fontBold),
      footer: (ctx) => _docFooter(ctx, font),
      build: (ctx) => [
        _sectionTitle('Situation financiere globale', fontBold),
        pw.SizedBox(height: 6),
        if (financialRows.isEmpty)
          _emptyNote('Aucune donnee financiere pour cette periode.', font)
        else
          _financialTable(financialRows, soldeReporte, font, fontBold),
        pw.SizedBox(height: 22),

        _sectionTitle('Situation par dossier', fontBold),
        pw.SizedBox(height: 6),
        if (dossierRows.isEmpty)
          _emptyNote('Aucune activite par dossier pour cette periode.', font)
        else
          _dossierTable(dossierRows, font, fontBold),
        pw.SizedBox(height: 22),

        _sectionTitle('Dossiers en souffrance de paiement', fontBold),
        pw.SizedBox(height: 6),
        if (souffranceRows.isEmpty)
          _emptyNote('Aucun dossier en souffrance.', font)
        else
          _souffranceTable(souffranceRows, font, fontBold),
      ],
    ));

    return doc.save();
  }

  /// Builds the MARINA Trans monthly report PDF (A4 landscape for wider tables).
  static Future<Uint8List> buildMarinasTrans({
    required String periodeLabel,
    required List<Map<String, Object?>> financialRows,
    required Map<String?, double> soldeReporte,
    required List<Map<String, Object?>> camionRows,
    required List<Map<String, Object?>> retourRows,
  }) async {
    final font     = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final doc      = pw.Document(title: 'Rapport mensuel MARINA Trans');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      header: (ctx) =>
          _docHeader('MARINA Trans', periodeLabel, font, fontBold),
      footer: (ctx) => _docFooter(ctx, font),
      build: (ctx) => [
        _sectionTitle('Situation financiere globale', fontBold),
        pw.SizedBox(height: 6),
        if (financialRows.isEmpty)
          _emptyNote('Aucune donnee financiere pour cette periode.', font)
        else
          _financialTable(financialRows, soldeReporte, font, fontBold),
        pw.SizedBox(height: 22),

        _sectionTitle('Detail par camion', fontBold),
        pw.SizedBox(height: 6),
        if (camionRows.isEmpty)
          _emptyNote('Aucun mouvement par camion pour cette periode.', font)
        else
          _camionTable(camionRows, font, fontBold),
        pw.SizedBox(height: 22),

        _sectionTitle('Retour Camion avec Charge', fontBold),
        pw.SizedBox(height: 6),
        if (retourRows.isEmpty)
          _emptyNote('Aucun retour camion pour cette periode.', font)
        else
          _retourTable(retourRows, font, fontBold),
      ],
    ));

    return doc.save();
  }

  // ── Document structure ─────────────────────────────────────────────────────

  static pw.Widget _docHeader(
      String company, String periode, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _cHeaderBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Rapport mensuel',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 13, color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text(company,
                  style: pw.TextStyle(
                      font: font, fontSize: 10, color: const PdfColor(1, 1, 1, 0.7))),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(periode,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 9, color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text('Imprime le ${_today()}',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: const PdfColor(1, 1, 1, 0.6))),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _docFooter(pw.Context ctx, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('MAKOSO App',
              style: pw.TextStyle(
                  font: font, fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: font, fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, pw.Font fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _cSectionBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Text(title,
          style: pw.TextStyle(
              font: fontBold, fontSize: 10, color: _cSectionText)),
    );
  }

  static pw.Widget _emptyNote(String msg, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _cBorder),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(msg,
          style: pw.TextStyle(font: font, fontSize: 9, color: _cGrey)),
    );
  }

  // ── Financial table ────────────────────────────────────────────────────────

  static pw.Widget _financialTable(
    List<Map<String, Object?>> rows,
    Map<String?, double> soldeReporte,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final hasReport = soldeReporte.values.any((v) => v != 0);

    final colWidths = hasReport
        ? {
            0: const pw.FlexColumnWidth(2.0),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(2.5),
            3: const pw.FlexColumnWidth(2.5),
            4: const pw.FlexColumnWidth(2.5),
          }
        : {
            0: const pw.FlexColumnWidth(2.0),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(2.5),
            3: const pw.FlexColumnWidth(2.5),
          };

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _cHeaderBg),
        children: [
          _th('MONNAIE', fontBold),
          if (hasReport) _th('REPORT', fontBold, right: true),
          _th('DEPOTS', fontBold, right: true),
          _th('DEPENSES', fontBold, right: true),
          _th('SOLDE', fontBold, right: true),
        ],
      ),
      for (int i = 0; i < rows.length; i++)
        () {
          final r = rows[i];
          final sigle =
              (r['sigle'] as String?) ?? (r['nom'] as String?) ?? '?';
          final depot = (r['total_depot'] as num?)?.toDouble() ?? 0.0;
          final depense = (r['total_depense'] as num?)?.toDouble() ?? 0.0;
          final report =
              soldeReporte[(r['monnaie_uuid'] as String?)] ?? 0.0;
          final solde = report + depot - depense;
          return pw.TableRow(
            decoration:
                pw.BoxDecoration(color: i.isOdd ? _cRowAlt : PdfColors.white),
            children: [
              _td(sigle, font, fontBold: fontBold, bold: true),
              if (hasReport)
                _td(_n(report), font, color: _cPurple, right: true),
              _td(_n(depot), font, color: _cBlue, right: true),
              _td(_n(depense), font, color: _cGrey, right: true),
              _td(_n(solde), font,
                  color: solde >= 0 ? _cGreen : _cRed,
                  fontBold: fontBold,
                  bold: true,
                  right: true),
            ],
          );
        }(),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _cBorder, width: 0.5),
      columnWidths: colWidths,
      children: tableRows,
    );
  }

  // ── Dossier table ──────────────────────────────────────────────────────────

  static pw.Widget _dossierTable(
    List<Map<String, Object?>> rows,
    pw.Font font,
    pw.Font fontBold,
  ) {
    // Group by dossier_uuid
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      grouped.putIfAbsent((r['dossier_uuid'] as String?) ?? '', () => []).add(r);
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _cHeaderBg),
        children: [
          _th('BL / CLIENT', fontBold),
          _th('STATUT', fontBold),
          _th('MONNAIE', fontBold),
          _th('DEPOTS', fontBold, right: true),
          _th('DEPENSES', fontBold, right: true),
          _th('SOLDE', fontBold, right: true),
        ],
      ),
    ];

    int rowIdx = 0;
    for (final entry in grouped.entries) {
      final dRows = entry.value;
      final first = dRows.first;
      final numeroBl  = (first['numero_bl']  as String?) ?? '-';
      final clientNom = (first['client_nom'] as String?) ?? '';
      final statut    = (first['statut']     as String?) ?? '-';
      final blLabel   = clientNom.isNotEmpty ? '$numeroBl\n$clientNom' : numeroBl;

      final active = dRows.where((r) {
        final d = (r['total_depot']   as num?)?.toDouble() ?? 0;
        final e = (r['total_depense'] as num?)?.toDouble() ?? 0;
        return d != 0 || e != 0;
      }).toList();

      final displayRows = active.isEmpty ? [dRows.first] : active;
      for (int i = 0; i < displayRows.length; i++) {
        final r      = displayRows[i];
        final sigle  = active.isEmpty ? '-' : ((r['monnaie_sigle'] as String?) ?? (r['monnaie_nom'] as String?) ?? '?');
        final depot  = active.isEmpty ? 0.0 : ((r['total_depot']   as num?)?.toDouble() ?? 0.0);
        final depense = active.isEmpty ? 0.0 : ((r['total_depense'] as num?)?.toDouble() ?? 0.0);
        final solde  = depot - depense;
        final bg     = rowIdx.isOdd ? _cRowAlt : PdfColors.white;
        tableRows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            _td(i == 0 ? blLabel : '', font, fontBold: fontBold, bold: i == 0),
            _td(i == 0 ? statut : '', font),
            _td(sigle, font),
            _td(active.isEmpty ? '-' : _n(depot), font, color: _cBlue, right: true),
            _td(active.isEmpty ? '-' : _n(depense), font, color: _cGrey, right: true),
            _td(active.isEmpty ? '-' : _n(solde), font,
                color: active.isEmpty ? _cGrey : (solde >= 0 ? _cGreen : _cRed),
                fontBold: fontBold,
                bold: active.isNotEmpty,
                right: true),
          ],
        ));
        rowIdx++;
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _cBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(2.0),
        4: pw.FlexColumnWidth(2.0),
        5: pw.FlexColumnWidth(2.0),
      },
      children: tableRows,
    );
  }

  // ── Souffrance table ───────────────────────────────────────────────────────

  static pw.Widget _souffranceTable(
    List<Map<String, Object?>> rows,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _cHeaderBg),
        children: [
          _th('BL', fontBold),
          _th('CLIENT', fontBold),
          _th('STATUT', fontBold),
          _th('SOUFFRANCE', fontBold),
        ],
      ),
      for (int i = 0; i < rows.length; i++)
        () {
          final r        = rows[i];
          final numeroBl = (r['numero_bl']   as String?) ?? '-';
          final client   = (r['client_nom']  as String?) ?? '-';
          final statut   = (r['statut']      as String?) ?? '-';
          final chips    = <String>[];
          if ((r['souffrance_draft']   as int? ?? 0) == 1) chips.add('30% Draft non paye');
          if ((r['souffrance_pn']      as int? ?? 0) == 1) chips.add('30% Pointe Noire non paye');
          if ((r['souffrance_matadi']  as int? ?? 0) == 1) chips.add('40% Matadi non paye');
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isOdd ? _cRowAlt : PdfColors.white),
            children: [
              _td(numeroBl, font, fontBold: fontBold, bold: true),
              _td(client, font),
              _td(statut, font),
              _td(chips.join(' | '), font, color: _cRed),
            ],
          );
        }(),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _cBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.0),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(4.0),
      },
      children: tableRows,
    );
  }

  // ── Camion table ───────────────────────────────────────────────────────────

  static pw.Widget _camionTable(
    List<Map<String, Object?>> rows,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      grouped.putIfAbsent((r['camion_uuid'] as String?) ?? '', () => []).add(r);
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _cHeaderBg),
        children: [
          _th('CAMION', fontBold),
          _th('MONNAIE', fontBold),
          _th('DEPOTS', fontBold, right: true),
          _th('DEP. VOYAGE', fontBold, right: true),
          _th('DEP. RETOUR', fontBold, right: true),
          _th('DEP. PANNE', fontBold, right: true),
          _th('TOT. DEP.', fontBold, right: true),
          _th('SOLDE', fontBold, right: true),
        ],
      ),
    ];

    int rowIdx = 0;
    for (final entry in grouped.entries) {
      final cRows = entry.value;
      final first  = cRows.first;
      final marque = (first['marque'] as String?) ?? '';
      final plaque = (first['plaque'] as String?) ?? '';
      final camionLabel =
          [marque, plaque].where((v) => v.isNotEmpty).join(' - ');

      final active = cRows.where((r) {
        final d  = (r['total_depot']            as num?)?.toDouble() ?? 0;
        final dv = (r['total_depense_voyage']   as num?)?.toDouble() ?? 0;
        final dr = (r['total_depense_retour']   as num?)?.toDouble() ?? 0;
        final dp = (r['total_depense_panne']    as num?)?.toDouble() ?? 0;
        return d != 0 || dv != 0 || dr != 0 || dp != 0;
      }).toList();

      final displayRows = active.isEmpty ? [cRows.first] : active;
      for (int i = 0; i < displayRows.length; i++) {
        final r    = displayRows[i];
        final sigle = (r['sigle'] as String?) ?? '?';
        final depot = (r['total_depot']          as num?)?.toDouble() ?? 0.0;
        final depV  = (r['total_depense_voyage'] as num?)?.toDouble() ?? 0.0;
        final depR  = (r['total_depense_retour'] as num?)?.toDouble() ?? 0.0;
        final depP  = (r['total_depense_panne']  as num?)?.toDouble() ?? 0.0;
        final totDep = depV + depR + depP;
        final solde = depot - totDep;
        final bg    = rowIdx.isOdd ? _cRowAlt : PdfColors.white;

        tableRows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            _td(i == 0 ? (camionLabel.isEmpty ? 'Camion sans nom' : camionLabel) : '',
                font, fontBold: fontBold, bold: i == 0),
            _td(active.isEmpty ? '-' : sigle, font),
            _td(active.isEmpty ? '-' : _n(depot), font, color: _cBlue, right: true),
            _td(active.isEmpty ? '-' : _n(depV), font, color: _cGrey, right: true),
            _td(active.isEmpty ? '-' : _n(depR), font, color: _cGrey, right: true),
            _td(active.isEmpty ? '-' : _n(depP), font, color: _cGrey, right: true),
            _td(active.isEmpty ? '-' : _n(totDep), font, color: _cDark, right: true),
            _td(active.isEmpty ? '-' : _n(solde), font,
                color: active.isEmpty ? _cGrey : (solde >= 0 ? _cGreen : _cRed),
                fontBold: fontBold,
                bold: active.isNotEmpty,
                right: true),
          ],
        ));
        rowIdx++;
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _cBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(2.0),
        4: pw.FlexColumnWidth(2.0),
        5: pw.FlexColumnWidth(2.0),
        6: pw.FlexColumnWidth(2.0),
        7: pw.FlexColumnWidth(2.0),
      },
      children: tableRows,
    );
  }

  // ── Retour table ───────────────────────────────────────────────────────────

  static pw.Widget _retourTable(
    List<Map<String, Object?>> rows,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final active = rows.where((r) {
      final d = (r['total_depot']   as num?)?.toDouble() ?? 0;
      final e = (r['total_depense'] as num?)?.toDouble() ?? 0;
      return d != 0 || e != 0;
    }).toList();

    if (active.isEmpty) {
      return _emptyNote(
          'Aucun mouvement Retour Camion avec Charge enregistre.', font);
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _cHeaderBg),
        children: [
          _th('MONNAIE', fontBold),
          _th('DEPOTS', fontBold, right: true),
          _th('DEPENSES', fontBold, right: true),
          _th('SOLDE', fontBold, right: true),
        ],
      ),
      for (int i = 0; i < active.length; i++)
        () {
          final r     = active[i];
          final sigle = (r['sigle'] as String?) ?? (r['monnaie_nom'] as String?) ?? '?';
          final depot = (r['total_depot']   as num?)?.toDouble() ?? 0.0;
          final dep   = (r['total_depense'] as num?)?.toDouble() ?? 0.0;
          final solde = depot - dep;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isOdd ? _cRowAlt : PdfColors.white),
            children: [
              _td(sigle, font, fontBold: fontBold, bold: true),
              _td(_n(depot), font, color: _cBlue, right: true),
              _td(_n(dep), font, color: _cGrey, right: true),
              _td(_n(solde), font,
                  color: solde >= 0 ? _cGreen : _cRed,
                  fontBold: fontBold,
                  bold: true,
                  right: true),
            ],
          );
        }(),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _cBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(2.5),
        3: pw.FlexColumnWidth(2.5),
      },
      children: tableRows,
    );
  }

  // ── Cell helpers ───────────────────────────────────────────────────────────

  static pw.Widget _th(
    String text,
    pw.Font fontBold, {
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Align(
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
              font: fontBold, fontSize: 8, color: PdfColors.white),
        ),
      ),
    );
  }

  static pw.Widget _td(
    String text,
    pw.Font font, {
    pw.Font? fontBold,
    bool bold = false,
    PdfColor? color,
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Align(
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: bold && fontBold != null ? fontBold : font,
            fontSize: 8,
            color: color ?? _cDark,
          ),
        ),
      ),
    );
  }
}
