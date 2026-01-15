"use client";

import { Document, Page, Text, View, StyleSheet, pdf } from "@react-pdf/renderer";

const styles = StyleSheet.create({
  page: {
    padding: 40,
    fontFamily: "Helvetica",
    backgroundColor: "#ffffff",
  },
  header: {
    marginBottom: 20,
    borderBottomWidth: 2,
    borderBottomColor: "#10b981",
    paddingBottom: 10,
  },
  title: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#1e293b",
  },
  subtitle: {
    fontSize: 12,
    color: "#64748b",
    marginTop: 4,
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: "bold",
    color: "#1e293b",
    marginBottom: 10,
    backgroundColor: "#f1f5f9",
    padding: 8,
  },
  statsGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
  },
  statBox: {
    width: "23%",
    padding: 10,
    backgroundColor: "#f8fafc",
    borderRadius: 4,
  },
  statLabel: {
    fontSize: 9,
    color: "#64748b",
    marginBottom: 4,
  },
  statValue: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#1e293b",
  },
  sgGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  sgBox: {
    width: "18%",
    padding: 8,
    backgroundColor: "#f8fafc",
    borderRadius: 4,
    alignItems: "center",
  },
  sgLabel: {
    fontSize: 8,
    color: "#64748b",
    marginBottom: 2,
  },
  sgValue: {
    fontSize: 14,
    fontWeight: "bold",
  },
  sgPositive: {
    color: "#10b981",
  },
  sgNegative: {
    color: "#f43f5e",
  },
  table: {
    marginTop: 10,
  },
  tableRow: {
    flexDirection: "row",
    borderBottomWidth: 1,
    borderBottomColor: "#e2e8f0",
    paddingVertical: 6,
  },
  tableHeader: {
    backgroundColor: "#f1f5f9",
    fontWeight: "bold",
  },
  tableCell: {
    flex: 1,
    fontSize: 10,
    textAlign: "center",
    color: "#1e293b",
  },
  tableCellLabel: {
    flex: 1,
    fontSize: 10,
    textAlign: "left",
    color: "#64748b",
    paddingLeft: 4,
  },
  footer: {
    position: "absolute",
    bottom: 30,
    left: 40,
    right: 40,
    textAlign: "center",
    fontSize: 9,
    color: "#94a3b8",
  },
});

interface RoundData {
  course_name: string;
  played_at: string;
  course_rating?: number | null;
  slope_rating?: number | null;
  total_score: number;
  total_putts?: number | null;
  fairways_hit?: number | null;
  fairways_total?: number | null;
  gir?: number | null;
  sg_total?: number | null;
  sg_off_tee?: number | null;
  sg_approach?: number | null;
  sg_around_green?: number | null;
  sg_putting?: number | null;
}

interface HoleData {
  hole_number: number;
  par: number;
  score: number;
  putts?: number | null;
  fairway_hit?: boolean | null;
  gir?: boolean | null;
}

interface RoundPDFProps {
  round: RoundData;
  holes: HoleData[];
}

const formatSG = (value: number | null | undefined) => {
  if (value === null || value === undefined) return "—";
  return value >= 0 ? `+${value.toFixed(2)}` : value.toFixed(2);
};

const RoundPDFDocument = ({ round, holes }: RoundPDFProps) => {
  const frontNine = holes.slice(0, 9);
  const backNine = holes.slice(9, 18);
  const totalPar = holes.reduce((sum, h) => sum + h.par, 0);

  return (
    <Document>
      <Page size="A4" style={styles.page}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>{round.course_name}</Text>
          <Text style={styles.subtitle}>
            {new Date(round.played_at).toLocaleDateString("en-US", {
              weekday: "long",
              year: "numeric",
              month: "long",
              day: "numeric",
            })}
            {round.course_rating && ` • Rating: ${round.course_rating}`}
            {round.slope_rating && ` • Slope: ${round.slope_rating}`}
          </Text>
        </View>

        {/* Score Summary */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Round Summary</Text>
          <View style={styles.statsGrid}>
            <View style={styles.statBox}>
              <Text style={styles.statLabel}>Total Score</Text>
              <Text style={styles.statValue}>{round.total_score}</Text>
            </View>
            <View style={styles.statBox}>
              <Text style={styles.statLabel}>To Par</Text>
              <Text style={styles.statValue}>
                {round.total_score - totalPar >= 0 ? "+" : ""}
                {round.total_score - totalPar}
              </Text>
            </View>
            <View style={styles.statBox}>
              <Text style={styles.statLabel}>Total Putts</Text>
              <Text style={styles.statValue}>{round.total_putts ?? "—"}</Text>
            </View>
            <View style={styles.statBox}>
              <Text style={styles.statLabel}>GIR</Text>
              <Text style={styles.statValue}>
                {round.gir ?? "—"}/18
              </Text>
            </View>
          </View>
        </View>

        {/* Strokes Gained */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Strokes Gained Analysis</Text>
          <View style={styles.sgGrid}>
            <View style={styles.sgBox}>
              <Text style={styles.sgLabel}>Total</Text>
              <Text style={[styles.sgValue, (round.sg_total ?? 0) >= 0 ? styles.sgPositive : styles.sgNegative]}>
                {formatSG(round.sg_total)}
              </Text>
            </View>
            <View style={styles.sgBox}>
              <Text style={styles.sgLabel}>Off Tee</Text>
              <Text style={[styles.sgValue, (round.sg_off_tee ?? 0) >= 0 ? styles.sgPositive : styles.sgNegative]}>
                {formatSG(round.sg_off_tee)}
              </Text>
            </View>
            <View style={styles.sgBox}>
              <Text style={styles.sgLabel}>Approach</Text>
              <Text style={[styles.sgValue, (round.sg_approach ?? 0) >= 0 ? styles.sgPositive : styles.sgNegative]}>
                {formatSG(round.sg_approach)}
              </Text>
            </View>
            <View style={styles.sgBox}>
              <Text style={styles.sgLabel}>Around Green</Text>
              <Text style={[styles.sgValue, (round.sg_around_green ?? 0) >= 0 ? styles.sgPositive : styles.sgNegative]}>
                {formatSG(round.sg_around_green)}
              </Text>
            </View>
            <View style={styles.sgBox}>
              <Text style={styles.sgLabel}>Putting</Text>
              <Text style={[styles.sgValue, (round.sg_putting ?? 0) >= 0 ? styles.sgPositive : styles.sgNegative]}>
                {formatSG(round.sg_putting)}
              </Text>
            </View>
          </View>
        </View>

        {/* Scorecard - Front Nine */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Scorecard - Front Nine</Text>
          <View style={styles.table}>
            <View style={[styles.tableRow, styles.tableHeader]}>
              <Text style={styles.tableCellLabel}>Hole</Text>
              {frontNine.map((h) => (
                <Text key={h.hole_number} style={styles.tableCell}>{h.hole_number}</Text>
              ))}
              <Text style={styles.tableCell}>Out</Text>
            </View>
            <View style={styles.tableRow}>
              <Text style={styles.tableCellLabel}>Par</Text>
              {frontNine.map((h) => (
                <Text key={h.hole_number} style={styles.tableCell}>{h.par}</Text>
              ))}
              <Text style={styles.tableCell}>{frontNine.reduce((s, h) => s + h.par, 0)}</Text>
            </View>
            <View style={styles.tableRow}>
              <Text style={styles.tableCellLabel}>Score</Text>
              {frontNine.map((h) => (
                <Text key={h.hole_number} style={styles.tableCell}>{h.score}</Text>
              ))}
              <Text style={styles.tableCell}>{frontNine.reduce((s, h) => s + h.score, 0)}</Text>
            </View>
            <View style={styles.tableRow}>
              <Text style={styles.tableCellLabel}>Putts</Text>
              {frontNine.map((h) => (
                <Text key={h.hole_number} style={styles.tableCell}>{h.putts ?? "—"}</Text>
              ))}
              <Text style={styles.tableCell}>{frontNine.reduce((s, h) => s + (h.putts || 0), 0)}</Text>
            </View>
          </View>
        </View>

        {/* Scorecard - Back Nine */}
        {backNine.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Scorecard - Back Nine</Text>
            <View style={styles.table}>
              <View style={[styles.tableRow, styles.tableHeader]}>
                <Text style={styles.tableCellLabel}>Hole</Text>
                {backNine.map((h) => (
                  <Text key={h.hole_number} style={styles.tableCell}>{h.hole_number}</Text>
                ))}
                <Text style={styles.tableCell}>In</Text>
                <Text style={styles.tableCell}>Tot</Text>
              </View>
              <View style={styles.tableRow}>
                <Text style={styles.tableCellLabel}>Par</Text>
                {backNine.map((h) => (
                  <Text key={h.hole_number} style={styles.tableCell}>{h.par}</Text>
                ))}
                <Text style={styles.tableCell}>{backNine.reduce((s, h) => s + h.par, 0)}</Text>
                <Text style={styles.tableCell}>{totalPar}</Text>
              </View>
              <View style={styles.tableRow}>
                <Text style={styles.tableCellLabel}>Score</Text>
                {backNine.map((h) => (
                  <Text key={h.hole_number} style={styles.tableCell}>{h.score}</Text>
                ))}
                <Text style={styles.tableCell}>{backNine.reduce((s, h) => s + h.score, 0)}</Text>
                <Text style={styles.tableCell}>{round.total_score}</Text>
              </View>
              <View style={styles.tableRow}>
                <Text style={styles.tableCellLabel}>Putts</Text>
                {backNine.map((h) => (
                  <Text key={h.hole_number} style={styles.tableCell}>{h.putts ?? "—"}</Text>
                ))}
                <Text style={styles.tableCell}>{backNine.reduce((s, h) => s + (h.putts || 0), 0)}</Text>
                <Text style={styles.tableCell}>{round.total_putts ?? "—"}</Text>
              </View>
            </View>
          </View>
        )}

        {/* Footer */}
        <Text style={styles.footer}>
          Generated by GolfStats • {new Date().toLocaleDateString()}
        </Text>
      </Page>
    </Document>
  );
};

export async function generateRoundPDF(round: RoundData, holes: HoleData[]): Promise<Blob> {
  const doc = <RoundPDFDocument round={round} holes={holes} />;
  const blob = await pdf(doc).toBlob();
  return blob;
}

export { RoundPDFDocument };

