DROP DATABASE ProduzioniVideo;
CREATE DATABASE IF NOT EXISTS ProduzioniVideo;
USE ProduzioniVideo;


-- Creazione tabelle database

CREATE TABLE Dipendente (
  CodiceFiscale CHAR(16) PRIMARY KEY,
  Nome VARCHAR(50) NOT NULL,
  Cognome VARCHAR(50) NOT NULL,
  Ruolo VARCHAR(15) NOT NULL,
  CHECK (Ruolo IN ('Polivalente', 'Operatore', 'Editor')),
  DataAssunzione DATE NOT NULL,
  Telefono VARCHAR(15) DEFAULT NULL,
  EmailAziendale VARCHAR(50) NOT NULL
);

CREATE TABLE Videocamera (
  NumeroSeriale VARCHAR(15) PRIMARY KEY,
  Modello VARCHAR(50) NOT NULL,
  Obiettivo VARCHAR(50) NOT NULL,
  Risoluzione VARCHAR(10) NOT NULL
);

CREATE TABLE Ripresa (
  CodiceRipresa INT PRIMARY KEY AUTO_INCREMENT,
  Giorno DATE NOT NULL,
  OrarioInizio TIME NOT NULL,
  Durata TIME NOT NULL,
  Salvataggio VARCHAR(80) NOT NULL,
  Dipendente CHAR(16) NOT NULL,
  Videocamera VARCHAR(15) NOT NULL,
  FOREIGN KEY (Dipendente) REFERENCES Dipendente (CodiceFiscale),
  FOREIGN KEY (Videocamera) REFERENCES Videocamera (NumeroSeriale)
);

CREATE TABLE Attore (
  CodiceFiscale CHAR(16) PRIMARY KEY,
  Nome VARCHAR(50) NOT NULL,
  Cognome VARCHAR(50) NOT NULL,
  DataNascita DATE NOT NULL,
  Telefono VARCHAR(15) NOT NULL
);

CREATE TABLE Recita (
  Attore CHAR(16),
  Ripresa INT,
  PRIMARY KEY (Attore, Ripresa),
  FOREIGN KEY (Attore) REFERENCES Attore (CodiceFiscale),
  FOREIGN KEY (Ripresa) REFERENCES Ripresa (CodiceRipresa)
);

CREATE TABLE Cliente (
  CodiceCliente INT PRIMARY KEY AUTO_INCREMENT,
  Nome VARCHAR(50) NOT NULL,
  NominativoReferente VARCHAR(50) NOT NULL,
  TelefonoReferente VARCHAR(15) DEFAULT NULL,
  Paese VARCHAR(50) NOT NULL,
  Città VARCHAR(50) NOT NULL,
  CAP VARCHAR(8) NOT NULL,
  Via VARCHAR(50) NOT NULL,
  Civico VARCHAR(8) NOT NULL
);

CREATE TABLE Video (
  CodiceVideo INT PRIMARY KEY AUTO_INCREMENT,
  Scadenza DATE NOT NULL,
  Stato CHAR(10) NOT NULL,
  CHECK (Stato IN ('Ripresa', 'Editing', 'Consegnato')),
  Titolo VARCHAR(80) NOT NULL,
  Cliente INT NOT NULL,
  FOREIGN KEY (Cliente) REFERENCES Cliente (CodiceCliente)
);

CREATE TABLE Montaggio (
  Versione INT,
  Video INT,
  Salvataggio VARCHAR(80) NOT NULL,
  Data DATE NOT NULL,
  Dipendente CHAR(16) NOT NULL,
  TempoImpiegato TIME NOT NULL,
  PRIMARY KEY (Versione, Video),
  FOREIGN KEY (Video) REFERENCES Video (CodiceVideo),
  FOREIGN KEY (Dipendente) REFERENCES Dipendente (CodiceFiscale)
);

CREATE TABLE Creazione (
  Ripresa INT,
  Versione INT,
  Video INT,
  PRIMARY KEY (Ripresa, Versione, Video),
  FOREIGN KEY (Ripresa) REFERENCES Ripresa (CodiceRipresa),
  FOREIGN KEY (Versione, Video) REFERENCES Montaggio (Versione, Video)
);

CREATE TABLE Fattura (
  NumeroFattura INT PRIMARY KEY AUTO_INCREMENT,
  Importo DECIMAL(10,2) NOT NULL,
  DataEmissione DATE NOT NULL,
  Video INT NOT NULL,
  DataPagamento DATE DEFAULT NULL,
  FOREIGN KEY (Video) REFERENCES Video (CodiceVideo)
);

CREATE TABLE Email (
  IndirizzoEmail VARCHAR(50) PRIMARY KEY,
  Cliente INT NOT NULL,
  FOREIGN KEY (Cliente) REFERENCES Cliente (CodiceCliente)
);


-- Trigger per controllo vincoli non esprimibili

-- Trigger per controllo sul ruolo in ripresa
DELIMITER $$
CREATE TRIGGER trg_RuoloRipresa BEFORE INSERT ON Ripresa
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
  IF ( (SELECT Ruolo FROM Dipendente WHERE CodiceFiscale = NEW.Dipendente) LIKE 'Editor' ) THEN
    SET Messaggio = CONCAT('Il dipendente ',NEW.Dipendente, ' non svolge compiti relativi al suo ruolo per la ripresa ', NEW.CodiceRipresa);
    SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;

-- Trigger per controllo sul ruolo in montaggio
DELIMITER $$
CREATE TRIGGER trg_RuoloMontaggio BEFORE INSERT ON Montaggio
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
    IF ( (SELECT Ruolo FROM Dipendente WHERE CodiceFiscale = NEW.Dipendente) LIKE 'Operatore' ) THEN
    SET Messaggio = CONCAT('Il dipendente ', NEW.Dipendente, ' non svolge compiti relativi al suo ruolo per il montaggio ', NEW.Video, ' ', NEW.Versione);
    SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;

-- Trigger per controllo sulla data di montaggio e relative riprese
DELIMITER $$
CREATE TRIGGER trg_DataMontaggio BEFORE INSERT ON Creazione
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
  IF (SELECT Data FROM Montaggio where NEW.Video = Video AND NEW.Versione = Versione) < (SELECT Giorno FROM Ripresa WHERE CodiceRipresa = NEW.Ripresa) THEN
    SET Messaggio = CONCAT('La data del montaggio deve essere successiva a quella della ripresa utilizzata. Valori errati: ', NEW.Ripresa, ', ', NEW.Versione, ', ', NEW.Video);
    SIGNAL SQLSTATE '45002' 
    SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;

-- Trigger per controllo sovrapposizioni riprese per stesso dipendente
DELIMITER $$
CREATE TRIGGER trg_SovrapposizioneRipreseDipendente BEFORE INSERT ON Ripresa
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
  IF EXISTS (
    SELECT * FROM Ripresa
    WHERE Dipendente = NEW.Dipendente
    AND Giorno = NEW.Giorno
    AND (  ( OrarioInizio <= NEW.OrarioInizio AND ADDTIME(OrarioInizio, Durata) >= NEW.OrarioInizio ) 
		OR ( OrarioInizio >= NEW.OrarioInizio AND ADDTIME(NEW.OrarioInizio, NEW.Durata) >= OrarioInizio )  )
     ) THEN
    SET Messaggio = CONCAT('Sovrapposizione di riprese per lo stesso dipendente in ripresa ', NEW.CodiceRipresa);
    SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;

-- Trigger per controllo sovrapposizioni riprese per stesso attore
DELIMITER $$
CREATE TRIGGER trg_SovrapposizioneRipreseAttore BEFORE INSERT ON Recita
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
  DECLARE Giorno DATE;
  DECLARE Orario TIME;
  DECLARE Durata TIME;
  SET Giorno = (SELECT p.Giorno FROM Ripresa p WHERE p.CodiceRipresa = NEW.Ripresa);
  SET Orario = (SELECT p.OrarioInizio FROM Ripresa p WHERE p.CodiceRipresa = NEW.Ripresa);
  SET Durata = (SELECT p.Durata FROM Ripresa p WHERE p.CodiceRipresa = NEW.Ripresa);
  IF EXISTS (
    SELECT * FROM Recita r JOIN Ripresa p ON r.Ripresa = p.CodiceRipresa
    WHERE r.Attore = NEW.Attore
    AND p.Giorno = Giorno
    AND (  ( p.OrarioInizio <= Orario AND ADDTIME(p.OrarioInizio, p.Durata) >= Orario ) 
		OR ( p.OrarioInizio >= Orario AND ADDTIME(Orario, Durata) >= p.OrarioInizio )  )
     ) THEN
    SET Messaggio = CONCAT('Sovrapposizione di riprese per lo stesso attore ', NEW.Attore, ' in ripresa: ', NEW.Ripresa);
    SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;

-- Trigger per controllo sovrapposizioni riprese per stessa videocamera
DELIMITER $$
CREATE TRIGGER trg_SovrapposizioneRipreseVideocamera
BEFORE INSERT ON Ripresa
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
  IF EXISTS (
    SELECT * FROM Ripresa
    WHERE Videocamera = NEW.Videocamera
    AND Giorno = NEW.Giorno
    AND (  ( OrarioInizio <= NEW.OrarioInizio AND ADDTIME(OrarioInizio, Durata) >= NEW.OrarioInizio ) 
		OR ( OrarioInizio >= NEW.OrarioInizio AND ADDTIME(NEW.OrarioInizio, NEW.Durata) >= OrarioInizio )  )
     ) THEN
    SET Messaggio = CONCAT('Sovrapposizione di riprese per la stessa videocamera in ripresa ', NEW.CodiceRipresa);
    SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;

-- Trigger per controllo update attributo Stato tabella Video
DELIMITER $$
CREATE TRIGGER trg_UpdateStato BEFORE UPDATE ON Video
FOR EACH ROW
BEGIN
  DECLARE Messaggio VARCHAR(200);
    IF ( NEW.Stato = 'Consegnato' AND NOT EXISTS (SELECT * FROM Montaggio WHERE NEW.CodiceVideo = Video) ) THEN
    SET Messaggio = CONCAT('Non è possibile aggiornare il video ', NEW.CodiceVideo, ', non sono presenti montaggi relativi!');
    SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = Messaggio;
  END IF;
END$$
DELIMITER ;


-- Azioni di interesse per il database

-- Lavori svolti (riprese e/o montaggi) da un determinato dipendente, ordinati per data
DELIMITER $$
CREATE PROCEDURE sp_getLavoriSvolti(
IN Nome VARCHAR(50),
IN Cognome VARCHAR(50)
)
BEGIN
SELECT 'Ripresa' AS TipoLavoro, r.Giorno AS DataLavoro, r.Salvataggio 
FROM Dipendente d
JOIN Ripresa r ON d.CodiceFiscale = r.Dipendente
WHERE d.Nome = Nome AND d.Cognome = Cognome
UNION
SELECT 'Montaggio' AS TipoLavoro, m.Data AS DataLavoro, m.Salvataggio 
FROM Dipendente d
JOIN Montaggio m ON d.CodiceFiscale = m.Dipendente
WHERE d.Nome = Nome AND d.Cognome = Cognome
ORDER BY DataLavoro;
END$$
DELIMITER ;

-- Video ancora da consegnare, in ordine di data scadenza
CREATE VIEW lavoriDaConsegnare AS
SELECT CodiceVideo, Titolo, Scadenza, Stato FROM Video 
WHERE Stato NOT LIKE "Consegnato"
ORDER BY Scadenza;

-- Fatture non pagate e dati dei relativi clienti
CREATE VIEW fattureNonPagate AS
SELECT NumeroFattura, DataEmissione, Importo AS ImportoEuro, CodiceCliente, Nome AS NomeCliente, Titolo AS TitoloVideo, Stato
FROM Fattura f JOIN Video v ON v.CodiceVideo = f.Video
JOIN Cliente c ON v.Cliente = c.CodiceCliente
WHERE DataPagamento IS NULL;

-- Posizione di salvataggio dei montaggi effettuati per ogni video di uno specifico cliente
DELIMITER $$
CREATE PROCEDURE sp_getSalvataggioMontaggi(
IN CodiceCliente INT
)
BEGIN
SELECT m.Video, m.Versione, m.Salvataggio
FROM Montaggio m
JOIN Video v ON v.CodiceVideo = m.Video
WHERE v.Cliente = CodiceCliente
ORDER BY v.CodiceVideo, m.Versione DESC;
END$$
DELIMITER ;


-- Gestione utenti (possono collegarsi solamente dal computer con il database, ognuno ha dei privilegi precisi)

DROP USER IF EXISTS datore@localhost;
CREATE USER datore@localhost
IDENTIFIED BY 'qwerty';

DROP USER IF EXISTS dipendente1@localhost;
CREATE USER dipendente1@localhost
IDENTIFIED BY '12345';

GRANT SELECT, UPDATE, INSERT, EXECUTE ON ProduzioniVideo.*
TO datore@localhost WITH GRANT OPTION;

GRANT SELECT ON lavoriDaConsegnare TO dipendente1@localhost;
GRANT EXECUTE ON PROCEDURE sp_getSalvataggioMontaggi TO dipendente1@localhost;


-- Altre viste per ottenere rapidamente dati

-- Vista per ottenere rapidamente clienti e fatture
CREATE VIEW ClienteFattura AS
SELECT CodiceCliente, Nome, NominativoReferente, TelefonoReferente, Paese, Città, CAP, Via,
Civico, NumeroFattura, Importo, DataPagamento, Video, DataEmissione
FROM Cliente JOIN Video ON CodiceCliente = Cliente
JOIN Fattura ON CodiceVideo = Video;