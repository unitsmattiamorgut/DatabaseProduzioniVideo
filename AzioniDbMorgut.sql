USE ProduzioniVideo;

-- Lavori svolti (riprese e/o montaggi) da un determinato dipendente, ordinati per data
SET @Nome = 'Matteo';
SET @Cognome = 'Martinelli';
CALL sp_getLavoriSvolti(@Nome, @Cognome);

-- Video ancora da consegnare, in ordine di data scadenza
SELECT * FROM lavoriDaConsegnare;

-- Fatture non pagate e dati dei relativi clienti
SELECT * FROM fattureNonPagate;

-- Posizione di salvataggio dei montaggi effettuati per ogni video di uno specifico cliente
SET @CodiceCliente = 16;
CALL sp_getSalvataggioMontaggi(@CodiceCliente);


-- Altre azioni, di minore interesse, per statistiche aziendali

-- Clienti con maggior spesa media per video nell'ultimo anno
SELECT CodiceCliente, Nome, AVG(Importo) AS Media_Importi FROM ClienteFattura
WHERE DataEmissione > DATE_SUB(CURRENT_DATE(), INTERVAL 1 YEAR)
GROUP BY CodiceCliente
ORDER BY Media_Importi DESC;

-- Visualizzare numero lavori effettuati da ogni dipendente, in ordine decrescente
SELECT Nome, Cognome, SUM(NumeroLavori) AS TotaleLavori
FROM (SELECT d.Nome, d.Cognome, COUNT(*) AS NumeroLavori
FROM Dipendente d
JOIN Ripresa r ON d.CodiceFiscale = r.Dipendente
GROUP BY d.CodiceFiscale
UNION DISTINCT
SELECT d.Nome, d.Cognome, COUNT(*) AS NumeroLavori
FROM Dipendente d
JOIN Montaggio m ON d.CodiceFiscale = m.Dipendente
GROUP BY d.CodiceFiscale) AS Dati
GROUP BY Nome, Cognome
ORDER BY TotaleLavori DESC;

-- Numero di utilizzi per ogni videocamera nell'ultimo anno
SELECT v.Modello, v.Obiettivo, COUNT(*) AS NumeroUtilizzi
FROM Videocamera v JOIN Ripresa r ON v.NumeroSeriale = r.Videocamera
WHERE Giorno > DATE_SUB(CURRENT_DATE(), INTERVAL 1 YEAR)
GROUP BY v.NumeroSeriale ORDER BY NumeroUtilizzi DESC;

-- Numero attori suddivisi per fascia d'età
SELECT '<18' AS Fascia, COUNT(*) AS NumeroAttori FROM Attore
WHERE FLOOR( DATEDIFF(CURDATE(), DataNascita) / 365 ) BETWEEN 0 AND 17
UNION
SELECT '18-40' AS Fascia, COUNT(*) AS NumeroAttori FROM Attore
WHERE FLOOR( DATEDIFF(CURDATE(), DataNascita) / 365 ) BETWEEN 18 AND 40
UNION
SELECT '41-60' AS Fascia, COUNT(*) AS NumeroAttori FROM Attore
WHERE FLOOR( DATEDIFF(CURDATE(), DataNascita) / 365 ) BETWEEN 41 AND 60
UNION
SELECT '>60' AS Fascia, COUNT(*) AS NumeroAttori FROM Attore
WHERE FLOOR( DATEDIFF(CURDATE(), DataNascita) / 365 ) > 60;


-- Altre operazioni, non di particolare interesse, ma comunque presentate

-- Riprese mai usate in un montaggio
SELECT CodiceRipresa FROM Ripresa
WHERE CodiceRipresa NOT IN (
  SELECT Ripresa
  FROM Creazione
) ORDER BY CodiceRipresa;

-- Numero riprese usate per ogni montaggio
SELECT m.Video, m.Versione, COUNT(c.Ripresa) AS NumeroRiprese
FROM Montaggio m LEFT JOIN Creazione c ON m.Versione = c.Versione AND m.Video = c.Video
GROUP BY m.Versione, m.Video ORDER BY NumeroRiprese DESC;

-- Montaggi che non hanno riprese assegnate
SELECT m.Video, m.Versione 
FROM Montaggio m LEFT JOIN Creazione c ON m.Versione = c.Versione AND m.Video = c.Video
GROUP BY m.Versione, m.Video HAVING COUNT(c.Ripresa) LIKE 0;

-- Mostra numero di clienti per ogni città
SELECT Città, COUNT(*) AS NumeroClienti FROM Cliente
GROUP BY Città ORDER BY  NumeroClienti DESC;

-- Clienti con maggior numero di video richiesti
SELECT Nome, COUNT(CodiceVideo) AS Numero_Video 
FROM Cliente JOIN Video ON Cliente = CodiceCliente
GROUP BY Cliente ORDER BY Numero_Video DESC;

-- Clienti con più soldi versati
SELECT Nome, SUM(Importo) AS Totale
FROM Cliente JOIN Video ON Cliente = CodiceCliente JOIN Fattura ON CodiceVideo = Video
GROUP BY Cliente ORDER BY Totale DESC;

-- Media importo per ogni video girato
SELECT AVG(Importo) AS Media_Importo€ FROM Fattura;