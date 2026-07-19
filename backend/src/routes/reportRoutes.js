const express = require('express');
const {
  createReport,
  deleteReport,
  generateReportFromUser,
  getReportById,
  listReports,
  listReportsByUser,
  updateReport,
} = require('../controllers/reportController');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();

router.use(requireAuth);

router.get('/', listReports);
router.get('/user/:userId', listReportsByUser);
router.post('/', createReport);
router.post('/generate/:userId', generateReportFromUser);
router.get('/:id', getReportById);
router.patch('/:id', updateReport);
router.delete('/:id', deleteReport);

module.exports = router;
