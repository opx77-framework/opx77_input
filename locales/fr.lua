--- @author DemiAutomatic
--- @file locales/fr.lua
--- @description French player-facing text for the input form.

OpxInput.Locale.register('fr', {
	['input.hint.edit'] = 'SAISIE',
	['input.hint.spin'] = '← → CHANGER',
	['input.hint.move'] = '↑ ↓ CHAMP',
	['input.hint.confirm'] = 'ENTRÉE VALIDER',
	['input.hint.cancel'] = 'ÉCHAP ANNULER',

	['input.refuse.required'] = 'Ce champ ne peut pas rester vide.',
	['input.refuse.format'] = "Cette valeur n'est pas acceptée ici.",
	['input.refuse.character'] = "Ce caractère n'est pas accepté ici.",
	['input.refuse.tooLong'] = 'Ce champ accepte au plus {max} caractères.',
})
