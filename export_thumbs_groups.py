#!/usr/bin/env python3
import inkex
from inkex.elements import Group, Layer
import os

class ExportThumbGroups(inkex.EffectExtension):

    def add_arguments(self, pars):
        pars.add_argument("--output_directory", type=str, help="Directory to save SVGs")

	def effect(self):
		doc = self.document
		thumbs_layer = None

		# Find the _thumbs layer
		for layer in doc.xpath('//svg:g[@inkscape:groupmode="layer"]', namespaces=inkex.NSS):
			label = layer.get(inkex.addNS('label', 'inkscape'))
			if label == "_thumbs":
				thumbs_layer = layer
				break

		if thumbs_layer is None:
			inkex.utils.debug("Layer '_thumbs' not found.")
			return

		output_dir = self.options.output_directory
		os.makedirs(output_dir, exist_ok=True)

		# Get base name of current file (without .svg extension)
		input_filename = os.path.splitext(os.path.basename(self.options.input_file))[0]

		for child in thumbs_layer:
			if isinstance(child, Group) and child.get('id'):
				group_id = child.get('id')
				output_path = os.path.join(output_dir, f"{input_filename}_{group_id}.svg")
				self.export_group(group_id, output_path)


    def export_group(self, group_id, output_path):
        self.document.write(self.args[-1])  # Update the temp SVG with current state

        cmd = [
            "inkscape",
            self.args[-1],
            f"--export-id={group_id}",
            "--export-type=svg",
            "--export-area-drawing",
            f"--export-filename={output_path}"
        ]

        inkex.command.call(cmd)

