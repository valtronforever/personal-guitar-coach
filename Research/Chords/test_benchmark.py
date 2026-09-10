import unittest
import numpy as np
from benchmark import exact_chord, match_attacks, estimate, attacks_from_notes, summarize

class ResearchContracts(unittest.TestCase):
    def test_identity_preserves_quality_and_abstains_on_omissions_and_extras(self):
        self.assertEqual(exact_chord([40,47,52,55,59,64]),'4:min')
        self.assertEqual(exact_chord([48,52,55,60]),'0:maj')
        for notes in [[],[40],[40,47],[48,52,55,58],[48,49,54]]:
            self.assertEqual(exact_chord(notes),'unknown')
    def test_match_is_one_to_one_and_maximizes_matches(self):
        result=match_attacks([0,.04],[.03,.08])
        self.assertEqual(result['matched'],2)
        self.assertEqual(match_attacks([1,1.01],[1])['matched'],1)
        self.assertEqual(match_attacks([1],[1.1])['matched'],0)
    def test_proxy_group_uses_first_onset_not_chained_neighbor(self):
        self.assertEqual(attacks_from_notes([{'onset_s':v} for v in [0,.05,.1]]),[0,.1])
    def test_silence_cannot_be_a_chord(self):
        result=estimate(np.zeros(4096))
        self.assertEqual(result['chroma'],'unknown');self.assertEqual(result['harmonic'],'unknown');self.assertEqual(result['notes'],[])
    def test_unknown_and_abstentions_stay_in_metrics(self):
        frames=[{'referenceChord':'0:maj','chroma':'0:maj','harmonic':'unknown','referenceNotes':[48,52,55],'notes':[]},
                {'referenceChord':'unknown','chroma':'0:maj','harmonic':'unknown','referenceNotes':[48],'notes':[]}]
        row={'split':'heldout','condition':'clean','frames':frames,'rhythm':{'errorsMs':[],'expected':2,'detected':0,'matched':0},'analysisWallSeconds':0,'audioSeconds':1}
        report=summarize([row])[0]
        self.assertEqual(report['identity']['chroma']['precision'],.5)
        self.assertEqual(report['identity']['chroma']['unknownFalseAcceptance'],1)
        self.assertEqual(report['identity']['harmonic']['recall'],0)
        self.assertIsNone(report['identity']['harmonic']['precision'])
        self.assertEqual(report['pitchSet']['fn'],4)
        self.assertEqual(report['rhythmProxy']['recall'],0)

if __name__=='__main__':unittest.main()
